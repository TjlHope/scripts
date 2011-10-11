#!/usr/bin/env python
""" Convert EEE Final Year Projects Web Page to a csv file.
"""

import sys
import re
import logging
from collections import namedtuple

from misc import argparse_, ic, output
from misc.wrappers import key, strip_html

def parse(argv=sys.argv[1:]):
    parser = argparse_.AuthArgumentParser(description=__doc__)
    parser.add_argument('-s', '--stream',
            choices=['4T', '4D', '4J', '3E', '3I', '1S', '1C'],
            help="Department Course Stream (Use 'J' for ISE4).")
    parser.add_argument('-o', '--output', default="projects",
            help="File name prefix to use for output (default: %(default)s).")
    args = parser.parse_args(argv)
    return args

def get_page(stream=None, user=None, passwd=None, **kwargs):
    """ Fetch projavail page from Imperial EEE intranet and return the html.
    """
    # Build URL
    url = "https://intranet.ee.ic.ac.uk/scripts2/projavail.asp"
    if stream:
        url += '?stream=' + stream
    # Try to get responce
    try:
        page = ic.form_redirect(url, user, passwd)
    except ic.HTTPError as err:
        # If error, exit
        sys.exit(2)
    return page

def get_projects(page, stream=None, sort='id'):
    """ Parse the html page to extract the data for each project.
    """
    log = logging.getLogger('ParseHTML')
    # Stream dependent initialization
    p_fields = ['id', 'supervisor', 'room', 'email', 'title', 'description']
    if not stream: p_fields.insert(4, 'streams')
    # Container definition
    Project = namedtuple('Project', p_fields)
    # Default project entry
    project_def = Project(*('',) * len(Project._fields))
    log.info(u"Storing project data with:\n\t\t{0}".format(project_def))
    # Get total number from page header
    total_str, page = page.split('<br><br><hr>', 1)
    total = int(total_str.rsplit('</b> ', 1)[-1])
    log.info(u"Page Header indicates {0} projects available.".format(total))
    # Init list of projects (start empty)
    projects = []
    for fields in page.split('<br><hr>'):
        for field in fields.split('<br><br>'):
            try:
                k, v = field.split('</b>', 1)
            except ValueError:
                log.info(u'Ignoring invalid field: """\n{0}\n"""'
                        .format(field))
                continue
            # Get field names to fit 'Project._fields' 
            k = key(k[3:])
            if k == 'projectid':
                try:
                    log.info(u"Add project {id}: {title}".format(**p_dict))
                    projects.append(project_def._replace(**p_dict))
                except UnboundLocalError: pass
                # ... and init new
                log.debug(u"Initiate project {0}.".format(v))
                p_dict = {'id': int(v)}
            elif k == 'supervisor':
                # Supervisor also has 'Room' and 'Email' fields
                for f in ': '.join((k, strip_html(v))).split('&nbsp; '):
                    k, v = f.split(':', 1)
                    p_dict[key(k)] = v.strip().replace('<br>', '')
                log.debug(u"Project {id} is run by {supervisor}." 
                                .format(**p_dict))
            else:
                p_dict[key(k)] = strip_html(v.strip()) #.replace('\n\r',''))
                log.debug(u"Add {0}: '{1}' to project {2}."
                                .format(k, p_dict[k], p_dict['id']))
    if sort:
        from operator import attrgetter
        projects.sort(key=attrgetter(sort))
    if len(projects) != total:
        log.warning(u"Parsed data for {0} projects, but page reports {1}."
                        .format(len(projects), total))
        log.info(u"Missing id ranges:\n{0}".format(
                    ["{0} -> {1}".format(projects[i].id + 1,
                                         projects[i + 1].id - 1)
                        for i in range(len(projects) - 1)
                            if projects[i].id + 1 != projects[i + 1].id]))
    return projects


if __name__ == '__main__':
    args = parse()
    logging.basicConfig(level=args.log_level)
    page = get_page(**args.__dict__)
    projects = get_projects(unicode(page, 'latin-1'), args.stream)
    output.table(projects, args.output)

