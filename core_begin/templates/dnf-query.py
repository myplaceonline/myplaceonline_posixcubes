#!/usr/bin/env python
#
# Query the dnf database for installed or available packages.
#
# This differs from dnf-repoquery in that it allows for querying
# packages based on version comparisons such as ">=".
#
# It also supports predictable sorting of package versions. The
# default behavior # is to show only the latest version. This can
# be changed with `--latest-limit=N`.
#
# Package names should match <package-spec> format here:
# http://dnf.readthedocs.org/en/latest/command_ref.html#specifying-packages-label
#
# Examples:
#
#   $ dnf-query.py tomcat
#   1:7.0.59-4.fc22.noarch
#
#   $ dnf-query.py tomcat --print-name
#   tomcat-1:7.0.59-4.fc22.noarch
#
#   $ dnf-query.py tomcat --installed
#   1:7.0.59-1.fc22.noarch
#
#   $ dnf-query.py tomcat '>=' 7.0.59-5
#   1:7.0.59-5.fc22.noarch
#   1:7.0.59-6.fc22.noarch
#
#   $ dnf-query.py sqlite.i686
#   3.8.10.2-1.fc22.i686
#
#   $ dnf-query.py sqlite.i686 '>= 3.7'
#   3.8.10.2-1.fc22.i686
#
#   $ dnf-query.py sqlite '>= 3.7' --latest-limit=3
#   3.8.10.2-1.fc22.x86_64
#   3.8.9-1.fc22.x86_64
#
#   $ dnf-query.py sqlite.i686 '>= 3.7' --latest-limit=3
#   3.8.10.2-1.fc22.i686
#   3.8.9-1.fc22.i686
#
#   $ dnf-query.py sqlite '>= 3.7' --latest-limit=1
#   3.8.10.2-1.fc22.x86_64
#

import dnf
import hawkey

# map human readable comparison operators to dnf's query language
# http://dnf.readthedocs.org/en/latest/api_queries.html#dnf.query.Query.filter
COMPARATOR_MAP = {
    '=':  'eq',
    '!=': 'neq',
    '>':  'gt',
    '>=': 'gte',
    '<':  'lt',
    '<=': 'lte',
}


def get_sack():
    base = dnf.Base()
    base.read_all_repos()
    base.fill_sack()
    return base.sack


def run(args):
    comparator = args.comparator
    version = None
    release = None

    if args.version:
        if '-' in args.version:
            version, release = args.version.split('-', 1)
        else:
            version = args.version
            release = None

    sack = get_sack()

    subj = dnf.subject.Subject(args.pkg_spec)

    q = subj.get_best_query(sack)
    q_kwargs = {}

    # We only show versions of a package matching a specific architecture, but provide support for matching
    # special 'noarch' packages as well.
    #
    # For example:
    # - if pkg_spec is 'systemd' and detected arch is x86_64, return 'systemd.x86_64' packages.
    # - if pkg_spec is 'systemd.i686', return 'systemd.i686' packages regardless of detected arch.
    # - if pkg_spec is 'tomcat', return 'tomcat.noarch' packages since there is no x86_64 version.
    #
    poss = dnf.util.first(subj.subj.nevra_possibilities_real(sack, allow_globs=True))
    if not poss:
        # no matching packages. we exit success with no output to match dnf-repoquery behavior
        return
    requested_arch = poss.arch

    if requested_arch:
        q_kwargs['arch'] = ['noarch', requested_arch]
    else:
        q_kwargs['arch'] = ['noarch', hawkey.detect_arch()]

    if args.installed:
        q = q.installed()
    else:
        q = q.available()

    if version:
        q_kwargs['version__{}'.format(COMPARATOR_MAP[args.comparator])] = version
    if release:
        q_kwargs['release__{}'.format(COMPARATOR_MAP[args.comparator])] = release

    q = q.filter(**q_kwargs)

    pkgs = dnf.query.latest_limit_pkgs(q, args.latest_limit)
    for pkg in pkgs:
        if args.print_name:
            print '{}-{}:{}-{}.{}'.format(pkg.name, pkg.epoch, pkg.version, pkg.release, pkg.arch)
        else:
            print '{}:{}-{}.{}'.format(pkg.epoch, pkg.version, pkg.release, pkg.arch)


if __name__ == '__main__':
    import argparse

    # @TODO(joe): Do we need to support enable/disable repo commands (--repo NAME)
    #             since the dnf provider (inherited from yum) has some support
    #             for passing repo opts to dnf?
    parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('pkg_spec', nargs='?',
                        help='The package name to query.')
    parser.add_argument('comparator', nargs='?',
                        help='comparsion function: =, >, >=, <, <=')
    parser.add_argument('version', nargs='?',
                        help='version specifier')

    parser.add_argument('--installed', action='store_true',
                       help='List installed packages instead of available packages.')
    parser.add_argument('--latest-limit', dest='latest_limit', type=int, default=1,
                       help='Show latest N matching packages.')
    parser.add_argument('--print-name', dest='print_name', action='store_true',
                       help='Print package name(s).')
    args = parser.parse_args()

    run(args)
