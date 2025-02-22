#!/usr/bin/python3

import yaml
import sys

def main():

    if len(sys.argv) == 3:
        file_path = sys.argv[1]
        build_for = sys.argv[2]
    else:
        return

    with open(file_path, "r") as file:

        try:
            data = yaml.safe_load(file)
        except yaml.YAMLError as exc:
            print(exc)

        for package in data:

            properties = data[package]

            architecture = properties['architecture']

            url = properties['source']

            if build_for in architecture:

                stable_ref = "none"
                testing_ref = "none"
                unstable_ref = "none"
                ros_test_enabled = False
                full_coverage = False

                refs = properties['git_refs']

                try:
                    stable_ref = refs['stable']
                except:
                    pass

                try:
                    testing_ref = refs['testing']
                except:
                    pass

                try:
                    unstable_ref = refs['unstable']
                except:
                    pass

                try:
                    ros_test = properties['ros_test']

                    try:
                        ros_test_enabled = bool(ros_test['enabled'])
                    except:
                        pass

                    try:
                        full_coverage = bool(ros_test['full_test_coverage'])
                    except:
                        pass
                except:
                    pass

                try:
                    gitman = bool(properties['gitman'])
                except:
                    pass

                print("{} {} {} {} {} {} {} {}".format(package, url, stable_ref, testing_ref, unstable_ref, ros_test_enabled, full_coverage, gitman))

if __name__ == '__main__':
    main()
