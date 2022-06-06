#!/usr/bin/env python3
"""
A wrapper around `charon-cmd` to provide easy access to an IPSec gateway,
supporting storing settings in an argument file, either given as
the first argument, or prefixed with '@'.

The argument file supports basic shell quoting, but no interpolation
(e.g. '"Do "Not" Separate"' => 'Do Not Separate', '$USER' => '$USER')
"""

import sys
import os
import logging
import argparse
import re
import shlex
try:
    from collections.abc import Sequence, Callable
except ImportError:
    from collections import Sequence, Callable
import itertools
from numbers import Number

import socket
import getpass

import pexpect
import subprocess


class WithLogger:
    log = None

    @classmethod
    def __init_subclass__(cls, logger_field='log',
                          logger_parent='.', logger_name='.',
                          **kwds):
        super().__init_subclass__(**kwds)
        logger_parent = cls._name(logger_parent, cls.__module__)
        logger_name = cls._name(logger_name, cls.__name__)
        setattr(cls, logger_field,
                cls.named([logger_parent, logger_name]))

    @classmethod
    def named(cls, names):
        if not names:
            return logging.getLogger()
        if isinstance(names, str) or not isinstance(names, Sequence):
            names = [names]
        if names[0] == '__main__':
            names = names[1:]
        names = ".".join(name for name in
                         (cls._name(name) for name in names if name)
                         if name)
        return logging.getLogger(names or None)

    @classmethod
    def _name(cls, s, default=None):
        if s is None:
            return None
        if isinstance(s, str):
            if s == ".":
                if default == "__main__":
                    return None
                return default
            return s
        if isinstance(s, logging.Logger):
            return None if s == logging.root else s.name
        if isinstance(s, type):
            return s.__module__ + "." + s.__name__
        return str(s)

    @classmethod
    def _enter(cls, name, *args, **kwds):
        parent = getattr(cls, 'log', cls)
        log = cls.named([parent, name])
        _level = kwds.pop('_level', logging.DEBUG)
        if log.isEnabledFor(_level):
            args = [repr(a) for a in args]
            if kwds:
                args.extend([k + "=" + repr(v) for k, v in kwds.items()])
            log.log(_level, "(" + ", ".join(args) + ")")
        return log


log = WithLogger.log = WithLogger.named(__name__)


class TypeAction(argparse.Action, WithLogger):
    __slots__ = ()

    def __init__(self, option_strings=None, dest=None, *args, **kwds):
        self._enter('__init__', option_strings, dest, *args, **kwds)
        super().__init__(option_strings, dest, *args, **kwds)

    def as_type(self, value):
        self._enter('as_type', value)
        return value

    def as_action(self, parser, namespace, values, option_string=None):
        self._enter('as_action', parser, namespace, values, option_string)
        new_values = []
        for value in values:
            new_value = self.as_type(value)
            if new_value is not argparse.SUPPRESS:
                new_values.append(new_value)
        if new_values:
            super().__call__(parser, namespace, new_values, option_string)

    def __call__(self, parser, namespace=None, values=None,
                 option_string=None):
        self._enter('__call__', parser, namespace, values, option_string)
        if namespace is None and values is None:
            return self.as_type(parser)
        if isinstance(values, str) or not isinstance(values, Sequence):
            values = [values]
        self.as_action(parser, namespace, values, option_string)


class Logfile(TypeAction):
    __slots__ = ('remove_default',)

    def __init__(self, *args, **kwds):
        self._enter('__init__', *args, **kwds)
        self.remove_default = kwds.pop('remove_default', True)
        super().__init__(*args, **kwds)

    @classmethod
    def is_default_handler(cls, handler):
        cls._enter('is_default_handler', handler)
        # formatter = getattr(handler, 'formatter', None)
        return (handler.__class__ == logging.StreamHandler and
                hasattr(handler, 'stream') and
                handler.stream == sys.stderr)  # and
        #        isinstance(formatter, logging.PercentStyle) and
        #        getattr(formatter, '_fmt', None) == logging.BASIC_FORMAT)

    @classmethod
    def get_formatter(cls):
        cls._enter('get_formatter')
        handlers = logging.root.handlers
        if not handlers:
            logging.basicConfig()
        handler = handlers[-1]
        return handler.formatter

    @classmethod
    def remove_default_handler(cls):
        cls._enter('remove_default_handler')
        handlers = logging.root.handlers
        if not handlers:
            logging.basicConfig()
        if len(handlers) == 1:
            handler = handlers[0]
            if cls.is_default_handler(handler):
                # looks like the default, so remove it
                logging.root.debug("removeHandler(%r)", handler)
                logging.root.removeHandler(handler)

    def as_type(self, value):
        self._enter('as_type', value)
        formatter = self.get_formatter()
        if self.remove_default:
            self.remove_default_handler()
        if value in ('-', '<stdout>'):
            handler = logging.StreamHandler(sys.stdout)
        elif value in ('<stderr>'):
            handler = logging.StreamHandler(sys.stderr)
        else:
            handler = logging.FileHandler(value)
        handler.setFormatter(formatter)
        logging.root.addHandler(handler)
        logging.root.debug("addHandler(%r)", handler)
        return argparse.SUPPRESS


class LogLevel(TypeAction):
    def as_type(self, value):
        self._enter('as_type', value)
        head, sep, tail = value.partition(':')
        if sep == ':':
            logging.getLogger(head).setLevel(tail)
        else:
            logging.root.setLevel(head)
        return argparse.SUPPRESS


class _ActionResult:
    __slots__ = ('action', 'values')

    def __init__(self, action, values):
        self.action = action
        if isinstance(values, str) or not isinstance(values, Sequence):
            values = [values]
        self.values = values

    @property
    def value(self):
        return self.values[0] if self.values else None

    @value.setter
    def value(self, val):
        if not self.values:
            self.values = [val]
        else:
            self.values[0] = val

    @property
    def is_option(self):
        return bool(self.action.option_strings)

    def params(self, compact=None):
        if self.is_option:
            opt = self.action.option_strings[0]
            if compact is None:
                # by default, only compact singulaly optional args
                compact = bool(self.action.nargs == argparse.OPTIONAL)
            result = []
            if compact:
                for val in self.values:
                    result.append(opt if val is None else opt + "=" + str(val))
            else:
                for val in self.values:
                    result.append(opt)
                    if val is not None:
                        result.append(str(val))
            return result
        else:
            return [str(val) for val in self.values]

    def __iter__(self):
        return iter(self.params())

    def __bool__(self):
        return bool(self.values and self.value)

    def __str__(self):
        return " ".join([shlex.quote(param) for param in self.params(True)])

    def __repr__(self):
        return (self.__class__.__name__ +
                '<' + self.action.dest + '>' +
                str(self.values))


class EnhancedArgumentParser(argparse.ArgumentParser, WithLogger):
    _NON_WORD_RE = re.compile(r'\W+')

    def __init__(self, *args, **kwds):
        self._enter('__init__', *args, **kwds)
        super().__init__(*args, **kwds)
        self.register('type', Default, lambda default: default())

    def parse_known_args(self, args=None, namespace=None):
        self._enter('parse_known_args', args, namespace)
        if namespace is None:
            namespace = LazyDefaultNamespace()
        return super().parse_known_args(args, namespace)

    def parse_arg_groups(self, args):
        self._enter('parse_arg_groups', args)
        parsed = self.parse_args(args)
        Namespace = with_iter(
            parsed.__class__,
            lambda self: itertools.chain.from_iterable(self.__dict__.values())
        )
        result = Namespace()
        i = 1
        for group in self._action_groups:
            if group.title:
                name = self._to_name(group.title)
            elif group == self._optionals:
                name = "optional_arguments"
            elif group == self._positionals:
                name = "positional_arguments"
            else:
                name = "unnamed_" + str(i)
                i += 1
            ns = Namespace()
            for action in group._group_actions:
                if hasattr(parsed, action.dest):
                    values = getattr(parsed, action.dest)
                    res = _ActionResult(action, values)
                    setattr(ns, action.dest, res)
            setattr(result, name, ns)
        return result

    def _to_name(self, s):
        self._enter('_to_name', s)
        return self._NON_WORD_RE.sub('_', s.lower()).strip('_')

    def _read_args_from_files(self, arg_strs, fromfile_prefix_chars=None):
        self._enter('_read_args_from_files', arg_strs, fromfile_prefix_chars)
        if not arg_strs:
            return arg_strs
        if fromfile_prefix_chars is None:
            fromfile_prefix_chars = self.fromfile_prefix_chars
        if not fromfile_prefix_chars:
            return arg_strs
        if 0 in fromfile_prefix_chars:
            fromfile_prefix_chars = set(fromfile_prefix_chars)
            fromfile_prefix_chars.remove(0)     # only ever the first arg
            arg_str = arg_strs[0]
            if (arg_str and
                    arg_str[0] not in self.prefix_chars and
                    arg_str[0] not in fromfile_prefix_chars):
                read_arg_strs = self.read_args_from_file_path(arg_str)
                arg_strs = read_arg_strs + arg_strs[1:]
        return self.read_args_from_files(arg_strs, fromfile_prefix_chars)

    def read_args_from_files(self, arg_strs, fromfile_prefix_chars):
        self._enter('read_args_from_files', arg_strs, fromfile_prefix_chars)
        if not arg_strs or not fromfile_prefix_chars:
            return arg_strs
        new_arg_strs = []
        for arg_str in arg_strs:
            # for regular arguments, just add them back into the list
            if not arg_str or arg_str[0] not in fromfile_prefix_chars:
                new_arg_strs.append(arg_str)
            # replace arguments referencing files with the file content
            else:
                read_arg_strs = self.read_args_from_file_path(arg_str[1:])
                # allow nesting
                read_arg_strs = self.read_args_from_files(
                    read_arg_strs, fromfile_prefix_chars)
                new_arg_strs.extend(read_arg_strs)
        # return the modified argument list
        return new_arg_strs

    def read_args_from_file_path(self, file_str):
        log = self._enter('read_args_from_file_path', file_str)
        try:
            head, sep, tail = file_str.partition(os.path.sep)
            log.debug("head=%r sep=%r tail=%r pathsep=%r", head, sep, tail,
                      os.path.sep)
            if head == "~":
                file_str = os.path.join(os.environ["HOME"], tail)
            with open(file_str) as args_file:
                return self.read_args_from_file(args_file)
        except OSError:
            err = sys.exc_info()[1]
            self.error(str(err))

    def read_args_from_file(self, args_file):
        self._enter('read_args_from_file', args_file)
        return shlex.split(args_file, comments=True)

    def convert_arg_line_to_args(self, arg_line):
        self._enter('convert_arg_line_to_args', arg_line)
        raise NotImplementedError()


class DefaultHelpFormatter(argparse.HelpFormatter):
    DEFAULTING_NARGS = [argparse.OPTIONAL, argparse.ZERO_OR_MORE]
    MULTIPLE_NARGS = [argparse.ZERO_OR_MORE, argparse.ONE_OR_MORE]

    def _get_help_string(self, action):
        default = action.default
        if (default is None or
                default is argparse.SUPPRESS or
                (isinstance(default, Default) and
                    default == argparse.SUPPRESS) or
                '%(default)' in action.help or
                not (action.option_strings or
                     action.nargs in self.DEFAULTING_NARGS)):
            return action.help
        return action.help + ' (default: %(default)s)'


class Default(str, WithLogger):
    __slots__ = ('_gen',)

    def __new__(cls, s, gen=None):
        cls._enter('__new__', s, gen=gen)
        obj = super().__new__(cls, s)
        if gen is not None:
            if isinstance(gen, Callable):
                obj._gen = gen
            else:
                obj._gen = lambda **kwargs: gen
        elif isinstance(s, Default):
            obj._gen = s.__call__
        else:
            obj._gen = lambda **kwargs: obj
        return obj

    def __call__(self, **kwds):
        self._enter('__call__', **kwds)
        return self._gen(**kwds)

    def __repr__(self):
        return '%s(%s)' % (self.__class__.__name__, super().__repr__())


class LazyDefault(WithLogger):
    __slots__ = ('type_func',)
    STR = None

    def __new__(cls, type_func=None):
        log = cls._enter('__new__', type_func=type_func)
        if type_func is None and isinstance(cls.STR, cls):
            log.debug("-> STR:%r", cls.STR)
            return cls.STR
        obj = super().__new__(cls)
        if type_func is None:
            obj.type_func = None
            cls.STR = obj
        else:
            obj.type_func = type_func
        log.debug("-> %r", obj)
        return obj

    def __call__(self, arg):
        log = self._enter('__call__', arg)
        try:
            if isinstance(arg, Default):
                arg = arg()
            if arg in (None, argparse.SUPPRESS):
                return arg
            if self.type_func is not None:
                arg = self.type_func(arg)
            return arg
        except Exception as e:
            log.debug("Exception: %s", e, exc_info=True)
            raise


class NamespaceDefault(Default):
    __slots__ = ()

    def __call__(self, **kwds):
        if 'namespace' not in kwds:
            return self
        return super().__call__(**kwds)


class LazyNamespaceDefault(LazyDefault):
    def __call__(self, arg):
        self._enter('__call__', arg)
        if isinstance(arg, Default):
            return NamespaceDefault(arg)
        return super().__call__(arg)


class LazyDefaultNamespace(argparse.Namespace, WithLogger):
    def __setattr__(self, name, value):
        self._enter('__setattr__', name, value)
        if isinstance(value, NamespaceDefault):
            value = value(namespace=self)
        if value is not argparse.SUPPRESS:
            self._enter("super.__setattr__", name, value)
            super().__setattr__(name, value)
        else:
            self._enter("super.__delattr__", name)
            super().__delattr__(name)


def with_iter(cls, __iter__):
    name = 'Iterable' + cls.__name__
    return type(name, (cls,), dict(__iter__=__iter__))


def file_path(path):
    if not os.path.isfile(path):
        raise TypeError("Not a file: " + path)


def ip_from_host(namespace, **kwds):
    host = namespace.host
    return socket.gethostbyname(host) if host else host


def host_or_ip(host):
    if host == "<IP>":
        return NamespaceDefault(host, ip_from_host)
    return host


def other_value(value):
    def get_value(namespace, **kwds):
        return getattr(namespace, value, argparse.SUPPRESS)
    return get_value


def getuser_if_profile(prefix):
    def getuser(namespace, **kwds):
        if namespace.profile and namespace.profile.startswith(prefix):
            return getpass.getuser()
        else:
            return argparse.SUPPRESS
    return getuser


def bool_str(s):
    if not s:
        return False
    if isinstance(s, Number):
        return bool(s)
    s = str(s).lower()
    if "true".startswith(s) or "yes".startswith(s) or "1" == s:
        return True
    if "false".startswith(s) or "no".startswith(s) or "0" == s:
        return False
    raise ValueError("Not a valid bool: " + str(s))


def parse(args):
    parser = EnhancedArgumentParser(
        description=__doc__,
        fromfile_prefix_chars={0, '@'},
        formatter_class=DefaultHelpFormatter)
    for group in parser._action_groups:
        group.title = None
    charon_group = parser.add_argument_group(
        "charon-cmd options", "Options passed to charon-cmd")
    charon_group.add_argument("--profile", metavar="<name>",
                              # Although strictly this isn't required, it
                              # doesn't really make sense to not provide it in
                              # this wrapper's case.
                              choices=[
                                  "ikev2-pub", "ikev2-eap", "ikev2-pub-eap",
                                  "ikev1-pub", "ikev1-pub-am",
                                  "ikev1-xauth", "ikev1-xauth-am",
                                  "ikev1-xauth-psk", "ikev1-xauth-psk-am",
                                  "ikev1-hybrid", "ikev1-hybrid-am"],
                              required=True,
                              help="authentication profile to use")
    charon_group.add_argument("--host", metavar="<hostname>",
                              required=True,
                              help="DNS name or address to connect to")
    charon_group.add_argument("--identity", metavar="<identity>",
                              type=LazyDefault(),
                              default=Default("current hostname",
                                              socket.gethostname),
                              help=("identity the client uses for the IKE "
                                    "exchange"))
    charon_group.add_argument("--eap-identity", metavar="<eap-identity>",
                              type=LazyNamespaceDefault(),
                              default=Default("current username",
                                              getuser_if_profile("ikev2")),
                              help=("identity the client uses for EAP "
                                    "authentication"))
    charon_group.add_argument("--xauth-username", metavar="<xauth-username>",
                              type=LazyNamespaceDefault(),
                              default=Default("current username",
                                              getuser_if_profile("ikev1")),
                              help=("username the client uses for XAuth "
                                    "authentication"))
    charon_group.add_argument("--remote-identity", metavar="<identity>",
                              # TODO: as help describes
                              type=LazyNamespaceDefault(host_or_ip),
                              default=Default("--host", other_value('host')),
                              help=("server identity to expect "
                                    "(<IP> to use the --host IP)"))
    charon_group.add_argument("--cert", metavar="<path>",
                              type=file_path, default=argparse.SUPPRESS,
                              help=("certificate for authentication or trust "
                                    "chain validation"))
    charon_group.add_argument("--rsa", metavar="<path>",
                              type=file_path, default=argparse.SUPPRESS,
                              help="RSA private key to use for authentication")
    charon_group.add_argument("--p12", metavar="<path>",
                              type=file_path, default=argparse.SUPPRESS,
                              help=("PKCS#12 file with private key and "
                                    "certificates to use for authentication "
                                    "and trust chain validation"))
    charon_group.add_argument("--agent", metavar="socket", nargs="?",
                              default=argparse.SUPPRESS,
                              help=("use SSH agent for authentication. If "
                                    "socket is not specified it is read from "
                                    "the SSH_AUTH_SOCK environment variable"))
    charon_group.add_argument("--local-ts", metavar="<subnet>",
                              default=argparse.SUPPRESS,
                              help=("additional traffic selector to propose "
                                    "for our side"))
    charon_group.add_argument("--remote-ts", metavar="<subnet>",
                              default=argparse.SUPPRESS,
                              help=("traffic selector to propose for remote "
                                    "side"))
    charon_group.add_argument("--ike-proposal", metavar="<proposal>",
                              action="append", default=argparse.SUPPRESS,
                              help=("an IKE proposal to offer instead of "
                                    "the default"))
    charon_group.add_argument("--esp-proposal", metavar="<proposal>",
                              action="append", default=argparse.SUPPRESS,
                              help=("an ESP proposal to offer instead of "
                                    "the default"))
    charon_group.add_argument("--ah-proposal", metavar="<proposal>",
                              action="append", default=argparse.SUPPRESS,
                              help=("an AH proposal to offer instead of "
                                    "the default"))
    charon_group.add_argument("--debug", metavar="<level>",
                              type=LazyDefault(int),
                              default=Default(1, argparse.SUPPRESS),
                              choices=range(-1, 4), help="set the log level")
    auth_group = parser.add_argument_group(
        "Authentication",
        "It is best to only use these in argument files")
    auth_group.add_argument("--psk", metavar="<psk>",
                            help="the Pre-shared key to use")
    auth_group.add_argument("--password", metavar="<passwd>",
                            action="append", default=[],
                            help=("a password to use for EAP/XAuth "
                                  "(specify multiple in the expected order)"))
    auth_group.add_argument("--pin", metavar="<pin>",
                            action="append", default=[],
                            help=("a PIN to use for EAP/XAuth "
                                  "(specify multiple in the expected order)"))
    # TODO
    auth_group.add_argument("--cache-auth", metavar="TRUE/false",
                            nargs=argparse.OPTIONAL, const=True,
                            type=bool_str, default=False,
                            help=("enable caching of manually entered auth, "
                                  "so won't work with MFA codes"))

    system_group = parser.add_argument_group(
        "System options",
        "Overrides for the default behaviour if required"
    )
    system_group.add_argument("--charon-cmd", metavar="<cmd>",
                              default="charon-cmd",
                              help=("location of the charon-cmd binary "
                                    "(will search PATH if appropriate)"))
    system_group.add_argument("--log-file", metavar="<log>",
                              type=Logfile(), default="-",
                              help="also supports -/<stdout> and <stderr>")
    system_group.add_argument("--log-level", metavar="level",
                              type=LazyDefault(LogLevel()),
                              default=Default(
                                  "INFO",
                                  lambda: os.environ.get(
                                      "CHARON_VPN_LOG_LEVEL", "INFO")
                              ),
                              help=("can be specified multiple times, "
                                    "either <log_level> or "
                                    "<logger_name>:<log_level>"))
    system_group.add_argument("--on-ip", metavar="<cmd>",
                              help=("command to run when charon-cmd installs "
                                    "a virtual IP, receives a single argument "
                                    "of the IP"))

    return parser.parse_arg_groups(args)


class PexpectLogger:
    __slots__ = ('log', 'level')

    def __init__(self, log, level):
        self.log = log
        self.level = level

    def write(self, s):
        for line in s.split('\n'):
            if line:
                self.log.log(self.level, line.rstrip())
        return len(s)

    def flush(self):
        pass


CHARON_CMD_EXPECT_TYPES = {
    "[IKE] initiating": ("state", "init"),
    "[IKE] IKE_SA cmd[1] established": ("state", "connected"),
    "[CFG] XAuth message: ": ("msg", "xauth"),
    "Preshared Key: ": ("auth", "psk"),
    "EAP password: ": ("auth", "password"),
    "EAP PIN: ": ("auth", "pin"),
    "[IKE] installing new virtual IP ": ("config", "ip"),
}
CHARON_CMD_EXPECT = list(CHARON_CMD_EXPECT_TYPES.keys())


def _iter_ns_values(ns, attr):
    return iter(getattr(ns, attr).values if hasattr(ns, attr) else [])


def get_auth(prompt='Enter password: '):
    if prompt and not prompt[-1].isspace():
        prompt += ': '
    # TODO look at ASKPASS env var?
    return getpass.getpass(prompt)


def run_vpn(args):
    log = WithLogger._enter('run_vpn', args)
    child = pexpect.spawn(args.system_options.charon_cmd.value,
                          list(args.charon_cmd_options),
                          encoding=sys.stdin.encoding)
    child.logfile_read = PexpectLogger(log.getChild('charon-cmd'),
                                       logging.DEBUG)
    log.debug("child.logfile_read = %r", child.logfile_read)
    auth = args.authentication
    try:
        current_auth = None
        connected = False
        last_msg = None
        while True:
            try:
                index = child.expect_exact(CHARON_CMD_EXPECT)
                found = CHARON_CMD_EXPECT[index]
                t, sub = CHARON_CMD_EXPECT_TYPES[found]
                if t == "state":
                    if sub == "init":
                        log.info("Initialising VPN connection to %s",
                                 args.charon_cmd_options.host.value)
                        connected = False
                        current_auth = {
                            'psk': _iter_ns_values(auth, 'psk'),
                            'password': _iter_ns_values(auth, 'password'),
                            'pin': _iter_ns_values(auth, 'pin'),
                        }
                    elif sub == "connected":
                        log.info("VPN connected")
                        connected = True
                    else:
                        log.warning("Ignoring unknown sub state: %s", sub)
                elif t == "auth":
                    if connected:
                        log.warning("Auth request (%s) whilst connected", sub)
                    if not current_auth:
                        # TODO: more info
                        log.error("No current auth state")
                        raise ValueError("No current auth state")
                    try:
                        val = next(current_auth[sub])
                    except StopIteration:
                        if last_msg is not None:
                            prompt = last_msg
                            last_msg = None
                        else:
                            prompt = found
                        val = get_auth(prompt)
                        if auth.cache_auth:
                            log.info("Caching authentication %s value", sub)
                            getattr(auth, sub).values.append(val)
                    child.sendline(val)
                elif t == "msg":
                    last_msg = child.readline().strip()
                elif t == "config":
                    if sub == "ip":
                        ip = child.readline().strip()
                        if not connected:
                            log.warning(("IP address (%s) installed when not "
                                         "connected"), ip)
                        if args.system_options.on_ip:
                            try:
                                subprocess.run(
                                    [args.system_options.on_ip.value, ip],
                                    check=True, timeout=10)
                            except subprocess.TimeoutExpired as e:
                                log.warning("Timed out waiting %ds for: %s",
                                            e.timeout, e.cmd)
                            except subprocess.CalledProcessError as e:
                                log.watning("Failed (%d) to run: %s",
                                            e.returncode, e.cmd)
            except pexpect.TIMEOUT:
                continue
            except pexpect.EOF:
                log.info("Received EOF, closing VPN")
                connected = False
                break
            except KeyboardInterrupt:
                log.info("Received SIGINT, interrupting VPN")
                child.sendintr()
                connected = False
                break
    finally:
        child.close(True)
    if child.exitstatus:
        log.warning("VPN exited with an error: %d", child.exitstatus)
    return child.exitstatus


def main(argv):
    WithLogger._enter('main', argv)
    args = parse(argv[1:])
    # TODO retry?
    return run_vpn(args)


if __name__ == "__main__":
    # initial logging setup
    logging.basicConfig(
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        level=os.environ.get("CHARON_VPN_LOG_LEVEL", logging.WARN),
    )
    sys.exit(main(sys.argv))
