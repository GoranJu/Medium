import { s__ } from '~/locale';

export const NAMESPACE_PROJECT = 'project';
export const NAMESPACE_GROUP = 'group';
export const NAMESPACE_ORGANIZATION = 'organization';

export const DEPENDENCIES_TABLE_I18N = {
  component: s__('Dependencies|Component'),
  packager: s__('Dependencies|Packager'),
  location: s__('Dependencies|Location'),
  unknown: s__('Dependencies|unknown'),
  license: s__('Dependencies|License'),
  projects: s__('Dependencies|Projects'),
  vulnerabilities: s__('Dependencies|Vulnerabilities'),
  tooltipText: s__(
    'Dependencies|The location includes the lock file. For transitive dependencies a list of its direct dependents is shown.',
  ),
  tooltipMoreText: s__('Dependencies|Learn more about direct dependents'),
  locationDependencyTitle: s__('Dependencies|List of direct dependents'),
  toggleVulnerabilityList: s__('Dependencies|Toggle vulnerability list'),
};
