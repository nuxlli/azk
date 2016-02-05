import h from 'spec/spec_helper';
import { lazy_require, config, version } from 'azk';
import nock from 'nock';
// import { async, all } from 'azk/utils/promises';

var lazy = lazy_require({
  VersionCheck: 'azk/agent/configure/checks/version_check',
  url: 'url',
  semver: 'semver',
});

describe("agent.configure.version_check module", function() {
  let outputs = [];
  let ui      = h.mockUI(beforeEach, outputs);
  let VersionCheck = lazy.VersionCheck;

  // For mock github call
  let github_url  = lazy.url.parse(config('urls:github:content:package_json'));
  let github_host = `${github_url.protocol}//${github_url.host}`;
  let github_path = github_url.path;

  afterEach(() => nock.cleanAll());

  it("should return true if the same version", function() {
    let github = nock(github_host).get(github_path).reply(200, { version });
    let result = VersionCheck.check().then((result) => {
      return { result, done: github.isDone() };
    });

    return h.expect(result).to.eventually.eql({result: true, done: true });
  });

  it("should return false if the version is higher than the current", function() {
    let newv   = lazy.semver.inc(version, 'patch');
    let github = nock(github_host).get(github_path).reply(200, { version: newv });

    let result = VersionCheck.check().then((result) => {
      return { result, done: github.isDone() };
    });

    return h.expect(result).to.eventually.eql({result: false, done: true });
  });

  it("should fail if is offline", function() {
    let net = {
      isOnlineCheck() { return false; }
    };
    let result = VersionCheck.check(ui, net).then((result) => {
      return { result, output: outputs[0] };
    });
    return h.expect(result).to.eventually
      .containSubset({result: false})
      .and.have.property("output")
      .and.match(h.regexFromT('configure.check_version_no_internet'));
  });
});
