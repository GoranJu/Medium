import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

const DAST_VARIABLES = {
  DAST_ACTIVE_SCAN_TIMEOUT: {
    type: 'Duration string',
    example: '3h',
    name: s__('DastProfiles|Active scan timeout'),
    description: {
      message: s__(
        'DastProfiles|The maximum amount of time to wait for the active scan phase of the scan to complete. Defaults to 3h.',
      ),
    },
  },
  DAST_ACTIVE_SCAN_WORKER_COUNT: {
    type: 'number',
    example: 3,
    name: s__('DastProfiles|Active scan worker count'),
    description: {
      message: s__('DastProfiles|The number of active checks to run in parallel. Defaults to 3.'),
    },
  },
  DAST_AUTH_AFTER_LOGIN_ACTIONS: {
    type: 'string',
    example: 'click(on=id:remember-me),click(on=css:.continue)',
    name: s__('DastProfiles|After-login actions'),
    description: {
      message: s__(
        'DastProfiles|A comma-separated list of actions to be run after login but before login verification. Currently supports `click` actions.',
      ),
    },
  },
  DAST_AUTH_BEFORE_LOGIN_ACTIONS: {
    type: 'selector',
    example: 'css:.user,id:show-login-form',
    name: s__('DastProfiles|Before-login actions'),
    description: {
      message: s__(
        'DastProfiles|A comma-separated list of selectors representing elements to click on prior to entering the DAST_AUTH_USERNAME and DAST_AUTH_PASSWORD into the login form.',
      ),
    },
  },
  DAST_AUTH_CLEAR_INPUT_FIELDS: {
    type: 'boolean',
    example: true,
    name: s__('DastProfiles|Clear input fields'),
    description: {
      message: s__(
        'DastProfiles|Disables clearing of username and password fields before attempting manual login. Set to false by default.',
      ),
    },
  },
  DAST_AUTH_COOKIE_NAMES: {
    type: 'string',
    example: 'sessionID,groupName',
    name: s__('DastProfiles|Cookie names'),
    description: {
      message: s__(
        'DastProfiles|Set to a comma-separated list of cookie names to specify which cookies are used for authentication.',
      ),
    },
  },
  DAST_AUTH_FIRST_SUBMIT_FIELD: {
    type: 'selector',
    example: 'css:input[type=submit]',
    name: s__('DastProfiles|First submit field'),
    description: {
      message: s__(
        'DastProfiles|A selector describing the element that is clicked on to submit the username form of a multi-page login process.',
      ),
    },
  },
  DAST_AUTH_NEGOTIATE_DELEGATION: {
    type: 'string',
    example: '*.example.com,example.com,*.EXAMPLE.COM,EXAMPLE.COM',
    name: s__('DastProfiles|Authentication delegation servers'),
    description: {
      message: s__(
        'DastProfiles|Which servers should be allowed for integrated authentication and delegation.',
      ),
    },
  },
  DAST_AUTH_SUCCESS_IF_AT_URL: {
    type: 'URL',
    example: 'https://www.site.com/welcome',
    name: s__('DastProfiles|Success URL'),
    description: {
      message: s__(
        'DastProfiles|A URL that is compared to the URL in the browser to determine if authentication has succeeded after the login form is submitted.',
      ),
    },
  },
  DAST_AUTH_SUCCESS_IF_ELEMENT_FOUND: {
    type: 'selector',
    example: 'css:.user-avatar',
    name: s__('DastProfiles|Success element'),
    description: {
      message: s__(
        'DastProfiles|A selector describing an element whose presence is used to determine if authentication has succeeded after the login form is submitted.',
      ),
    },
  },
  DAST_AUTH_SUCCESS_IF_NO_LOGIN_FORM: {
    type: 'boolean',
    example: true,
    name: s__('DastProfiles|Success without login form'),
    description: {
      message: s__(
        'DastProfiles|Verifies successful authentication by checking for the absence of a login form after the login form has been submitted. This success check is enabled by default.',
      ),
    },
  },
  DAST_AUTH_TYPE: {
    type: 'string',
    example: 'basic-digest',
    name: s__('DastProfiles|Authentication type'),
    description: { message: s__('DastProfiles|The authentication type to use.') },
  },
  DAST_CRAWL_EXTRACT_ELEMENT_TIMEOUT: {
    type: 'Duration string',
    example: '5s',
    name: s__('DastProfiles|Extract element timeout'),
    description: {
      message: s__(
        'DastProfiles|The maximum amount of time to allow the browser to extract newly found elements or navigations. Defaults to `5s`.',
      ),
    },
  },
  DAST_CRAWL_MAX_ACTIONS: {
    type: 'number',
    example: '10000',
    name: s__('DastProfiles|Maximum action count'),
    description: {
      message: s__(
        'DastProfiles|The maximum number of actions that the crawler performs. Example actions include selecting a link, or filling out a form. Defaults to `10000`.',
      ),
    },
  },
  DAST_CRAWL_MAX_DEPTH: {
    type: 'number',
    example: '10',
    name: s__('DastProfiles|Maximum action depth'),
    description: s__(
      'DastProfiles|The maximum number of chained actions that the crawler takes. For example, `Click, Form Fill, Click` is a depth of three. Defaults to `10`.',
    ),
  },
  DAST_CRAWL_SEARCH_ELEMENT_TIMEOUT: {
    type: 'Duration string',
    example: '3s',
    name: s__('DastProfiles|Element search timeout'),
    description: {
      message: s__(
        'DastProfiles|The maximum amount of time to allow the browser to search for new elements or user actions. Defaults to `3s`.',
      ),
    },
  },
  DAST_CRAWL_TIMEOUT: {
    type: 'Duration string',
    example: '5m',
    name: s__('DastProfiles|Timeout'),
    description: {
      message: s__(
        'DastProfiles|The maximum amount of time to wait for the crawl phase of the scan to complete. Defaults to `24h`.',
      ),
    },
  },
  DAST_CRAWL_WORKER_COUNT: {
    type: 'number',
    example: '3',
    name: s__('DastProfiles|Worker count'),
    description: {
      message: s__(
        'DastProfiles|The maximum number of concurrent browser instances to use. For instance runners on GitLab.com, we recommended a maximum of three. Private runners with more resources may benefit from a higher number, but are likely to produce little benefit after five to seven instances. The default value is dynamic, equal to the number of usable logical CPUs.',
      ),
    },
  },
  DAST_PAGE_DOM_READY_TIMEOUT: {
    type: 'Duration string',
    example: '7s',
    name: s__('DastProfiles|DOM ready timeout'),
    description: {
      message: s__(
        'DastProfiles|The maximum amount of time to wait for a browser to consider a page loaded and ready for analysis after a navigation completes. Defaults to `6s`.',
      ),
    },
  },
  DAST_PAGE_DOM_STABLE_WAIT: {
    type: 'Duration string',
    example: '200ms',
    name: s__('DastProfiles|DOM stable timeout'),
    description: {
      message: s__(
        'DastProfiles|Define how long to wait for updates to the DOM before checking a page is stable. Defaults to `500ms`.',
      ),
    },
  },
  DAST_PAGE_ELEMENT_READY_TIMEOUT: {
    type: 'Duration string',
    example: '600ms',
    name: s__('DastProfiles|Page ready timeout'),
    description: {
      message: s__(
        'DastProfiles|The maximum amount of time to wait for an element before determining it is ready for analysis. Defaults to `300ms`.',
      ),
    },
  },
  DAST_PAGE_IS_LOADING_ELEMENT: {
    type: 'selector',
    example: 'css:#page-is-loading',
    name: s__('DastProfiles|Loading element'),
    description: {
      message: s__(
        'DastProfiles|Selector that, when no longer visible on the page, indicates to the analyzer that the page has finished loading and the scan can continue. Cannot be used with `DAST_PAGE_IS_READY_ELEMENT`.',
      ),
    },
  },
  DAST_PAGE_IS_READY_ELEMENT: {
    type: 'selector',
    example: 'css:#page-is-ready',
    name: s__('DastProfiles|Ready element'),
    description: {
      message: s__(
        'DastProfiles|Selector that when detected as visible on the page, indicates to the analyzer that the page has finished loading and the scan can continue. Cannot be used with `DAST_PAGE_IS_LOADING_ELEMENT`.',
      ),
    },
  },
  DAST_PAGE_MAX_RESPONSE_SIZE_MB: {
    type: 'number',
    example: '15',
    name: s__('DastProfiles|Maximum response size (MB)'),
    description: {
      message: s__(
        'DastProfiles|The maximum size of a HTTP response body. Responses with bodies larger than this are blocked by the browser. Defaults to `10` MB.',
      ),
    },
  },
  DAST_PAGE_READY_AFTER_ACTION_TIMEOUT: {
    type: 'Duration string',
    example: '7s',
    name: s__('DastProfiles|Page ready timeout (after action)'),
    description: {
      message: s__(
        'DastProfiles|The maximum amount of time to wait for a browser to consider a page loaded and ready for analysis. Defaults to `7s`.',
      ),
    },
  },
  DAST_PAGE_READY_AFTER_NAVIGATION_TIMEOUT: {
    type: 'Duration string',
    example: '15s',
    name: s__('DastProfiles|Page ready timeout (after navigation)'),
    description: {
      message: s__(
        'DastProfiles|The maximum amount of time to wait for a browser to navigate from one page to another. Defaults to `15s`.',
      ),
    },
  },
  DAST_PASSIVE_SCAN_WORKER_COUNT: {
    type: 'int',
    example: '5',
    name: s__('DastProfiles|Passive scan worker count'),
    description: {
      message: s__(
        'DastProfiles|Number of workers that passive scan in parallel. Defaults to the number of available CPUs.',
      ),
    },
  },
  DAST_PKCS12_CERTIFICATE_BASE64: {
    type: 'string',
    example: 'ZGZkZ2p5NGd...',
    name: s__('DastProfiles|PKCS12 certificate'),
    description: {
      message: s__(
        'DastProfiles|The PKCS12 certificate used for sites that require Mutual TLS. Must be encoded as base64 text.',
      ),
    },
  },
  DAST_PKCS12_PASSWORD: {
    type: 'string',
    example: 'password',
    name: s__('DastProfiles|PKCS12 password'),
    description: {
      message: s__(
        'DastProfiles|The password of the certificate used in `DAST_PKCS12_CERTIFICATE_BASE64`. Create sensitive %{linkStart}custom CI/CI variables%{linkEnd} using the GitLab UI.',
      ),
      path: helpPagePath('ci/variables/_index', { anchor: 'define-a-cicd-variable-in-the-ui' }),
    },
  },
  DAST_REQUEST_ADVERTISE_SCAN: {
    type: 'boolean',
    example: true,
    name: s__('DastProfiles|Advertise scan'),
    description: {
      message: s__(
        'DastProfiles|Set to `true` to add a `Via` header to every request sent, advertising that the request was sent as part of a GitLab DAST scan. Default: `false`.',
      ),
    },
  },
  DAST_REQUEST_COOKIES: {
    type: 'dictionary',
    example: 'abtesting_group:3,region:locked',
    name: s__('DastProfiles|Request cookies'),
    description: {
      message: s__('DastProfiles|A cookie name and value to be added to every request.'),
    },
  },
  DAST_SCOPE_ALLOW_HOSTS: {
    type: 'List of strings',
    example: 'site.com,another.com',
    name: s__('DastProfiles|Allowed hosts'),
    description: {
      message: s__(
        'DastProfiles|Hostnames included in this variable are considered in scope when crawled. By default the `DAST_TARGET_URL` hostname is included in the allowed hosts list. Headers set using `DAST_REQUEST_HEADERS` are added to every request made to these hostnames.',
      ),
    },
  },
  DAST_SCOPE_EXCLUDE_ELEMENTS: {
    type: 'selector',
    example: "a[href='2.html'],css:.no-follow",
    name: s__('DastProfiles|Excluded elements'),
    description: {
      message: s__(
        'DastProfiles|Comma-separated list of selectors that are ignored when scanning.',
      ),
    },
  },
  DAST_SCOPE_EXCLUDE_HOSTS: {
    type: 'List of strings',
    example: 'site.com,another.com',
    name: s__('DastProfiles|Excluded hosts'),
    description: {
      message: s__(
        'DastProfiles|Hostnames included in this variable are considered excluded and connections are forcibly dropped.',
      ),
    },
  },
  DAST_SCOPE_IGNORE_HOSTS: {
    type: 'List of strings',
    example: 'site.com,another.com',
    name: s__('DastProfiles|Ignored hosts'),
    description: {
      message: s__(
        'DastProfiles|Hostnames included in this variable are accessed, not attacked, and not reported against.',
      ),
    },
  },
  DAST_TARGET_CHECK_SKIP: {
    type: 'boolean',
    example: true,
    name: s__('DastProfiles|Skip target check'),
    description: {
      message: s__(
        'DastProfiles|Set to `true` to prevent DAST from checking that the target is available before scanning. Default: `false`.',
      ),
    },
  },
  DAST_TARGET_CHECK_TIMEOUT: {
    type: 'number',
    example: '60',
    name: s__('DastProfiles|Target check timeout'),
    description: {
      message: s__(
        'DastProfiles|Time limit in seconds to wait for target availability. Default: `60s`.',
      ),
    },
  },
  DAST_TARGET_PATHS_FILE: {
    type: 'string',
    example: '/builds/project/urls.txt',
    name: s__('DastProfiles|Target paths file'),
    description: {
      message: s__(
        'DastProfiles|Ensures that the provided paths are always scanned. Set to a file path containing a list of URL paths relative to `DAST_TARGET_URL`. The file must be plain text with one path per line.',
      ),
    },
  },
  DAST_TARGET_PATHS: {
    type: 'string',
    example: '/page1.html,/category1/page3.html',
    name: s__('DastProfiles|Target paths'),
    description: {
      message: s__(
        'DastProfiles|Ensures that the provided paths are always scanned. Set to a comma-separated list of URL paths relative to `DAST_TARGET_URL`.',
      ),
    },
  },
  DAST_USE_CACHE: {
    type: 'boolean',
    example: true,
    name: s__('DastProfiles|Use cache'),
    description: {
      message: s__(
        'DastProfiles|Set to `false` to disable caching. Default: `true`. **Note:** Disabling cache can cause OOM events or DAST job timeouts.',
      ),
    },
  },
};

export default DAST_VARIABLES;
