import {
  SAST_SHORT_NAME,
  DAST_SHORT_NAME,
  DEPENDENCY_SCANNING_NAME,
  SECRET_DETECTION_NAME,
  CONTAINER_SCANNING_NAME,
  SAST_IAC_SHORT_NAME,
} from '~/security_configuration/constants';

/* eslint-disable @gitlab/require-i18n-strings */

// These options apply to all analyzers.
const COMMON_OPTIONS = ['SECURE_LOG_LEVEL'];

// These options apply to both SAST and SAST-IaC.
const SAST_COMMON_OPTIONS = ['SAST_IMAGE_SUFFIX', 'SAST_ANALYZER_IMAGE_TAG'];

// These options apply to source code-based analyzers (SAST, SAST-IaC, SD).
const SAST_SD_COMMON_OPTIONS = [
  'SECURE_ENABLE_LOCAL_CONFIGURATION',
  'SECURE_ANALYZERS_PREFIX', // This is not available in CS; otherwise it could be in COMMON_OPTIONS.
];

export const OPTIONS = {
  [DAST_SHORT_NAME]: [
    ...COMMON_OPTIONS,
    'DAST_ADVERTISE_SCAN',
    'DAST_BROWSER_ACTION_STABILITY_TIMEOUT',
    'DAST_BROWSER_ACTION_TIMEOUT',
    'DAST_BROWSER_ALLOWED_HOSTS',
    'DAST_BROWSER_COOKIES',
    'DAST_BROWSER_CRAWL_GRAPH',
    'DAST_BROWSER_CRAWL_TIMEOUT',
    'DAST_BROWSER_DEVTOOLS_LOG',
    'DAST_BROWSER_DOM_READY_AFTER_TIMEOUT',
    'DAST_BROWSER_ELEMENT_TIMEOUT',
    'DAST_BROWSER_EXCLUDED_ELEMENTS',
    'DAST_BROWSER_EXCLUDED_HOSTS',
    'DAST_BROWSER_EXTRACT_ELEMENT_TIMEOUT',
    'DAST_BROWSER_FILE_LOG',
    'DAST_BROWSER_FILE_LOG_PATH',
    'DAST_BROWSER_IGNORED_HOSTS',
    'DAST_BROWSER_INCLUDE_ONLY_RULES',
    'DAST_BROWSER_LOG',
    'DAST_BROWSER_LOG_CHROMIUM_OUTPUT',
    'DAST_BROWSER_MAX_ACTIONS',
    'DAST_BROWSER_MAX_DEPTH',
    'DAST_BROWSER_MAX_RESPONSE_SIZE_MB',
    'DAST_BROWSER_NAVIGATION_STABILITY_TIMEOUT',
    'DAST_BROWSER_NAVIGATION_TIMEOUT',
    'DAST_BROWSER_NUMBER_OF_BROWSERS',
    'DAST_BROWSER_PAGE_LOADING_SELECTOR',
    'DAST_BROWSER_PAGE_READY_SELECTOR',
    'DAST_BROWSER_PASSIVE_CHECK_WORKERS',
    'DAST_BROWSER_SCAN',
    'DAST_BROWSER_SEARCH_ELEMENT_TIMEOUT',
    'DAST_BROWSER_STABILITY_TIMEOUT',
    'DAST_EXCLUDE_RULES',
    'DAST_EXCLUDE_URLS',
    'DAST_FF_ENABLE_BAS',
    'DAST_FULL_SCAN_ENABLED',
    'DAST_PATHS',
    'DAST_PATHS_FILE',
    'DAST_PKCS12_CERTIFICATE_BASE64',
    'DAST_PKCS12_PASSWORD',
    'DAST_REQUEST_HEADERS',
    'DAST_SKIP_TARGET_CHECK',
    'DAST_TARGET_AVAILABILITY_TIMEOUT',
    'DAST_WEBSITE',
    'SECURE_ANALYZERS_PREFIX',
  ],
  [SAST_SHORT_NAME]: [
    ...COMMON_OPTIONS,
    ...SAST_COMMON_OPTIONS,
    ...SAST_SD_COMMON_OPTIONS,
    'SAST_EXCLUDED_ANALYZERS',
    'SAST_EXCLUDED_PATHS',
    'SEARCH_MAX_DEPTH',
    'SAST_RULESET_GIT_REFERENCE',
    'SCAN_KUBERNETES_MANIFESTS',
    'KUBESEC_HELM_CHARTS_PATH',
    'KUBESEC_HELM_OPTIONS',
    'COMPILE',
    'ANT_HOME',
    'ANT_PATH',
    'GRADLE_PATH',
    'JAVA_OPTS',
    'JAVA_PATH',
    'SAST_JAVA_VERSION',
    'MAVEN_CLI_OPTS',
    'MAVEN_PATH',
    'MAVEN_REPO_PATH',
    'SBT_PATH',
    'FAIL_NEVER',
    'SAST_SEMGREP_METRICS',
    'SAST_SCANNER_ALLOWED_CLI_OPTS',
    'GITLAB_ADVANCED_SAST_ENABLED',
  ],
  [SAST_IAC_SHORT_NAME]: [...COMMON_OPTIONS, ...SAST_COMMON_OPTIONS, ...SAST_SD_COMMON_OPTIONS],
  [DEPENDENCY_SCANNING_NAME]: [
    ...COMMON_OPTIONS,
    'ADDITIONAL_CA_CERT_BUNDLE',
    'DS_EXCLUDED_ANALYZERS',
    'DS_EXCLUDED_PATHS',
    'DS_IMAGE_SUFFIX',
    'DS_INCLUDE_DEV_DEPENDENCIES',
    'DS_JAVA_VERSION',
    'DS_MAX_DEPTH',
    'DS_PIP_DEPENDENCY_PATH',
    'DS_PIP_VERSION',
    'DS_REMEDIATE_TIMEOUT',
    'DS_REMEDIATE',
    'SECURE_ANALYZERS_PREFIX',
  ],
  [CONTAINER_SCANNING_NAME]: [
    ...COMMON_OPTIONS,
    'ADDITIONAL_CA_CERT_BUNDLE',
    'CI_APPLICATION_REPOSITORY',
    'CI_APPLICATION_TAG',
    'CS_ANALYZER_IMAGE',
    'CS_DEFAULT_BRANCH_IMAGE',
    'CS_DISABLE_LANGUAGE_VULNERABILITY_SCAN',
    'CS_DOCKER_INSECURE',
    'CS_IMAGE_SUFFIX',
    'CS_IGNORE_UNFIXED',
    'CS_REGISTRY_INSECURE',
    'CS_SEVERITY_THRESHOLD',
    'CS_IMAGE',
    'CS_REGISTRY_PASSWORD',
    'CS_REGISTRY_USER',
    'CS_DOCKERFILE_PATH',
    'CS_QUIET',
    'CS_IGNORE_STATUSES',
    'CS_TRIVY_JAVA_DB',
  ],
  [SECRET_DETECTION_NAME]: [
    ...COMMON_OPTIONS,
    ...SAST_SD_COMMON_OPTIONS,
    'SECRET_DETECTION_EXCLUDED_PATHS',
    'SECRET_DETECTION_HISTORIC_SCAN',
    'SECRET_DETECTION_IMAGE_SUFFIX',
    'SECRET_DETECTION_LOG_OPTIONS',
    'SECRET_DETECTION_RULESET_GIT_REFERENCE',
  ],
};
