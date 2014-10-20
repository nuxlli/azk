import { _, fs, config, async, set_config, lazy_require } from 'azk';
import { Command, Helpers } from 'azk/cli/command';
import { AGENT_CODE_ERROR } from 'azk/utils/errors';

lazy_require(this, {
  Client() {
    return require('azk/agent/client').Client;
  },

  Configure() {
    return require('azk/agent/configure').Configure;
  },
});

class Cmd extends Command {
  action(opts) {
    // Create a progress output
    var progress = Helpers.vmStartProgress(this);

    return async(this, function* () {
      // Only in start
      if (opts.action === 'start') {
        // And no running
        var status = yield Client.status();
        if (!status.agent) {
          // Check and load configures
          this.warning('status.agent.wait');
          opts.configs = yield Helpers.configure(this);

          // Remove and adding vm (to refresh vm configs)
          if (config('agent:requires_vm') && opts['reload-vm']) {
            var cmd_vm = this.parent.commands.vm;
            yield cmd_vm.action({ action: 'remove', fail: () => {} });
          }
        }
      }

      // Call action in agent
      var promise = Client[opts.action](opts).progress(progress);
      return promise.then((result) => {
        if (opts.action != "status") return result;
        return (result.agent) ? 0 : 1;
      });
    });
  }
}

export function init(cli) {
  var cli = (new Cmd('agent {action}', cli))
    .setOptions('action', { options: ['start', 'status', 'stop'] })
    .addOption(['--daemon', '-d'], { default: true });

  if (config('agent:requires_vm')) {
    cli.addOption(['--reload-vm', '-d'], { default: true });
  }
}
