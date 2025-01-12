local snmp = import 'github.com/thaum-xyz/jsonnet-libs/apps/snmp-exporter/snmp-exporter.libsonnet';
local snmpConfig = importstr '../snmp.yml';

local configYAML = (importstr '../settings.yaml');

// Join multiple configuration sources
local config = std.parseYaml(configYAML)[0] {
  configData: snmpConfig,
};

local probe(name, namespace, labels, module, targets, interval) = {
  apiVersion: 'monitoring.coreos.com/v1',
  kind: 'Probe',
  metadata: {
    name: name,
    namespace: namespace,
    labels: labels,
  },
  spec: {
    prober: {
      url: 'snmp-exporter.' + namespace + '.svc:9116',
      path: '/snmp',
    },
    module: module,
    targets: {
      staticConfig: {
        labels: {
          module: module,
        },
        static: targets,
      },
    },
    interval: interval,
    scrapeTimeout: interval,
  },
};

local all = snmp(config) + {
  qnapProbe: probe(
    config.targets[0].module,
    config.namespace,
    $.deployment.metadata.labels,
    config.targets[0].module,
    config.targets[0].hosts,
    config.targets[0].interval
  ),
  qnaplongProbe: probe(
    config.targets[1].module,
    config.namespace,
    $.deployment.metadata.labels,
    config.targets[1].module,
    config.targets[1].hosts,
    config.targets[1].interval
  ),
  prometheusRule: {
    apiVersion: "monitoring.coreos.com/v1",
    kind: "PrometheusRule",
    metadata: {
      name: config.name,
      namespace: config.namespace,
      labels: $.deployment.metadata.labels,
    },
    spec: {
      groups: [{
        name: "qnap",
        rules: [
          {
            alert: "QNAPDiskFailure",
            expr: "diskSmartInfo != 0",
            "for": "15m",
            labels: {
              severity: "critical",
            },
            annotations: {
              summary: "QNAP hard drive is faulty",
              description: "SMART data for hard drives number {{ $labels.diskIndex }} on QNAP NAS {{ $labels.instance }} reports disk failure. Disk most probably needs to be replaced as soon as possible.",
              //runbook_url: ""
            },
          },
          {
            alert: "QNAPFirmwareAvailable",
            expr: "firmwareUpgradeAvailable != 0",
            "for": "24h",
            labels: {
              severity: "info",
            },
            annotations: {
              summary: "QNAP NAS firmware upgrade available",
              description: "QNAP NAS {{ $labels.instance }} has pending firmware upgrade.",
              //runbook_url: ""
            },
          },
          {
            alert: "QNAPVolumeNotReady",
            expr: "volumeStatus != 0",
            "for": "2h",
            labels: {
              severity: "warning",
            },
            annotations: {
              summary: "QNAP volume is not ready",
              description: "Data Volume number {{ $labels.volumeIndex }} on QNAP {{ $labels.instance }} is not ready for last 2h.",
              //runbook_url: ""
            },
          },
          {
            alert: "QNAPVolumeNotReady",
            expr: "volumeStatus < 0",
            "for": "10m",
            labels: {
              severity: "critical",
            },
            annotations: {
              summary: "QNAP volume is in critical state",
              description: "Data Volume number {{ $labels.volumeIndex }} on QNAP {{ $labels.instance }} is in critical state and needs immediate attention.",
              //runbook_url: ""
            },
          },
          {
            alert: "QNAPRAIDProblem",
            expr: "raidStatus < 0",
            "for": "20m",
            labels: {
              severity: "critical",
            },
            annotations: {
              summary: "QNAP RAID is in error state",
              description: "RAID array number {{ $labels.raidIndex }} on QNAP {{ $labels.instance }} is in critical state and needs immediate attention.",
              //runbook_url: ""
            },
          },
          {
            alert: "QNAPRAIDProblem",
            expr: "raidStatus != 0",
            "for": "12h",
            labels: {
              severity: "warning",
            },
            annotations: {
              summary: "QNAP RAID is in warning state",
              description: "RAID array number {{ $labels.raidIndex }} on QNAP {{ $labels.instance }} is in warning state for last 12h.",
              //runbook_url: ""
            },
          },
        ],
      }],
    },
  },
};

{ [name + '.yaml']: std.manifestYamlDoc(all[name]) for name in std.objectFields(all) }
