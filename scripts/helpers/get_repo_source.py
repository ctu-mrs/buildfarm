#!/usr/bin/python3

import yaml
import sys

def main():

    if len(sys.argv) == 5:
        file_path = sys.argv[1]
        variant = sys.argv[2]
        build_for = sys.argv[3]
        repo_name = sys.argv[4]
    else:
        return

    with open(file_path, "r") as file:

        try:
            data = yaml.safe_load(file)
        except yaml.YAMLError as exc:
            print(exc)

        properties = data[repo_name]

        architecture = properties['architecture']

        url = properties['source']

        if build_for in architecture:

            refs = properties['git_refs']

            if variant == "stable":
                ref = refs['stable']
            elif variant == "unstable":
                ref = refs['unstable']
            else:
                ref = refs['testing']

            try:
                gitman = bool(properties['gitman'])
            except:
                pass

            print("{} {} {} {}".format(repo_name, url, ref, gitman))

if __name__ == '__main__':
    main()
