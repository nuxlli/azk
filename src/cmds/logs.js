import { log, _, async, defer, config, Q, t } from 'azk';
import { Command, Helpers } from 'azk/cli/command';
import { Manifest } from 'azk/manifest';
import { ReadableStream } from 'memory-streams';
import docker from 'azk/docker';

var moment  = require('moment');

class Cmd extends Command {
  action(opts) {
    return async(this, function* () {
      yield Helpers.requireAgent();

      var manifest = new Manifest(this.cwd, true);
      var systems  = Helpers.getSystemsByName(manifest, opts.system);

      yield this.logs(manifest, systems, opts);
    });
  }

  make_out(output, name) {
    return {
      write(data) {
        data = data.toString().match(/^\[(.*?)\](.*\n)$/m);
        output.write(`${data[1].magenta} ${name}:${data[2]}`);
      }
    }
  }

  connect(system, color, instances, options) {
    return _.map(instances, (instance) => {
      var name = `${system.name}${instance.Annotations.azk.seq}`[color];
      var container = docker.getContainer(instance.Id);
      var stdout = this.make_out(process.stdout, name);
      var stderr = this.make_out(process.stderr, name);

      return container.logs(options).then((stream) => {
        return defer((resolve, reject) => {
          if (_.isString(stream)) {
            stream = new ReadableStream(stream);
          }
          container.modem.demuxStream(stream, stdout, stderr);
          stream.on('end', resolve);
        });
      });
    });
  }

  logs(manifest, systems, opts = {}) {
    var options = {
      stdout: true,
      stderr: true,
      tail: opts.lines,
      timestamps: opts.timestamps,
    };

    if (opts.follow) {
      options.follow = true;
    }

    var colors = ["green", "yellow", "blue", "red", "cyan", "grey"];
    var color  = -1;

    return Q.all(_.map(systems, (system) => {
      return system.instances({ type: "daemon" }).then((instances) => {
        color++;
        return Q.all(this.connect(system, colors[color % colors.length], instances, options));
      });
    }));
  }
}

export { Cmd };
export function init(cli) {
  (new Cmd('logs [system]', cli))
    .addOption(['--follow', '--tail', '-f'], { default: false })
    .addOption(['--lines', '-n'], { type: Number, default: "all" })
    .addOption(['--timestamps'], { default: true });
}

