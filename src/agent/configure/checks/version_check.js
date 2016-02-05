import { lazy_require, config, version } from 'azk';
import { async } from 'azk/utils/promises';

var lazy = lazy_require({
  net: ["azk/utils"],
  UI : ['azk/cli/ui'],
  rq : 'request-promise',
  semver: 'semver',
});

var VersionCheck = {
  check(ui = lazy.ui, net = lazy.net) {
    return async(this, function*() {
      // check connectivity
      var currentOnline = yield net.isOnlineCheck();
      if ( !currentOnline ) {
        ui.warning('configure.check_version_no_internet');
        return false;
      }

      // get AZK version from Github API
      let body = yield lazy.rq({
        uri : config('urls:github:content:package_json'),
        headers: { 'User-Agent': 'Request-Promise' },
        json: true,
        simple: true,
      });

      // compare versions
      var azkLatestVersion    = lazy.semver.clean(body.version);
      var newAzkVersionExists = lazy.semver.lt(version, azkLatestVersion);

      return !newAzkVersionExists;
    });
  }
};

export default VersionCheck;
