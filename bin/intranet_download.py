#!/usr/bin/env python
# SCRIPTS_DIR/bin/intranet_download.py
""" Download a page [recursively] from the EE intranet.
"""

import sys
import os
import re
import logging

from misc import argparse_, ic
# from misc.wrappers import key, strip_html

log = logging.getLogger('Downloader')


def parse(argv=sys.argv[1:]):
    parser = argparse_.AuthArgumentParser(description=__doc__)
    parser.add_argument('url', help="URL to download.")
    parser.add_argument('-r', '-R', '--recursive', action="store_true",
            help="Download web site recursively.")
    parser.add_argument('-o', '-O', '--output', action="store_true",
            help="File name to use for output (default: page name).")
    args = parser.parse_args(argv)
    return args


def write_page(text, file_name, **kwds):
    path = os.path.expanduser(file_name).split('/')
    for i in range(1, len(path)):
        name = os.path.join(*path[:i])
        if not os.path.isdir(name):
            log.debug("Making directory '{0}'.".format(name))
            os.mkdir(name, 0755)
    name = os.path.join(*path)
    with open(name, 'wb') as fl:
        log.info("Saving page '{0}'.".format(name))
        fl.write(text)
    return name


def get_page(url, browser, **kwds):
    """ Fetch page from Intranet.
    """
    # Try to get responce
    page = browser.redirect_open(url)
    output = kwds['output']
    if kwds['recursive']:
        file_name = page.geturl().rpartition('://')[2]
        if isinstance(output, basestring):
            file_name = output + '/' + file_name.split('/', 1)[1]
    else:
        if isinstance(output, basestring):
            file_name = output
        else:
            file_name = page.geturl().rpartition('/')[2]
    page.seek(0)
    text = page.read()
    write_page(text, file_name, **kwds)
    if browser.viewing_html():
        return text


link_re = re.compile("""<a\s.*?href=(['"])(.*?)\\1[\s>]""")
def get_links(page, links=[], **kwds):
    # TODO: test given links to prevent loops?
    links += [match.group(2) for match in link_re.finditer(page)]
    return links


def recurse_page(url, browser=None, user=None, passwd=None, **kwds):
    if not browser:
        browser = ic.FormRedirectBrowser()
        if user:
            browser.add_password(url, user, passwd)
    try:
        page = get_page(url, browser, **kwds)
        num = 1
        if page:
            for link in get_links(page):
                num += recurse_page(ic.quote(link), browser, **kwds)
        return num
    except ic.Error:
        log.warning("Failed to get '{0}'".format(url))
        return 0


if __name__ == '__main__':
    args = parse()
    logging.basicConfig(level=args.log_level)
    if args.recursive:
        num = recurse_page(**args.__dict__)
        log.info("Recursively got {0} page{1}."
                        .format(num, '' if num == 1 else 's'))
    else:
        page = get_page(**args.__dict__)
        log.info("Got page and saved to '{0}'.".format(page))
    sys.exit(0)
