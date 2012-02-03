#!/usr/bin/env python
# SCRIPTS_DIR/bin/intranet_download.py
""" Download a page [recursively] from the EE intranet.
"""

import sys
import re
import logging

from misc import argparse_, ic
# from misc.wrappers import key, strip_html


def parse(argv=sys.argv[1:]):
    parser = argparse_.AuthArgumentParser(description=__doc__)
    parser.add_argument('url', help="URL to download.")
    parser.add_argument('-r', '-R', '--recursive', action="store_true",
            help="Download web site recursively.")
    parser.add_argument('-o', '-O', '--output', action="store_true",
            help="File name to use for output (default: page name).")
    args = parser.parse_args(argv)
    return args


def get_page(url, user=None, passwd=None, **kwds):
    """ Fetch page from Intranet.
    """
    # Try to get responce
    try:
        page = ic.formopen(url, user, passwd)
    except ic.Error:
        # If error, exit
        sys.exit(2)
    page.seek(0)
    return page.read()

def write_page(page, output, recursive=None, **kwds):
    pass

link_re = re.compile("""<a\s.*?\shref=(['"])(.*?)\1[\s>]""")
def get_links(page, links=[], **kwds):
    # TODO: test given links to prevent loops?
    links += [match.group(1) for match in link_re.finditer(page)]
    return links


def recurse_page(url, **kwds):
    page = get_page(url, **kwds)
    num = [recurse_page(link, **kwds) for link in get_links(page)]
    return sum(num) + 1


if __name__ == '__main__':
    args = parse()
    logging.basicConfig(level=args.log_level)
    if args.recursive:
        num = recurse_page(**args.__dict__)
        logging.info("Recursively got {0} page{1}."
                        .format(num, '' if num == 1 else 's'))
    else:
        page = get_page(**args.__dict__)
        logging.info("Got page and saved to '{0}'.".format(page))
    sys.exit(0)
