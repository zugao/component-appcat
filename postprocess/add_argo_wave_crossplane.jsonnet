local com = import 'lib/commodore.libjsonnet';
local inv = com.inventory();

local addArgoWave(obj) =
  obj {
    metadata+: {
      annotations: {
        'argocd.argoproj.io/sync-wave': '-100',
      },
    },
  };

com.fixupDir(std.extVar('output_path'), addArgoWave)
