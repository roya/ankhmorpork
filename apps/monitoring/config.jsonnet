// convert file to yaml when jsonnet supports yaml imports (https://github.com/google/jsonnet/pull/888)
// Figure out how to merge configuration as `std.mergePatch` may not be enough

{
  common+: {
    namespace: 'monitoring',
    ruleLabels: {
      role: 'alert-rules',
    },
    baseDomain: 'ankhmorpork.thaum.xyz',
  },
  alertmanager+: {
    resources: {
      requests: { memory: '30Mi' },
    },
  },
  prometheus+: {
    version: '2.28.0',  // application-version-from-github: prometheus/prometheus
    image: 'quay.io/prometheus/prometheus:v2.28.0',  // application-image-from-github: prometheus/prometheus
    externalLabels: {
      cluster: "ankhmorpork",
    },
    ruleSelector: {},
    resources: {
      requests: { cpu: '140m', memory: '1900Mi' },
      limits: { cpu: '1' },
    },
  },
  prometheusOperator+: {
    mixin+: {
      _config: {
        prometheusOperatorSelector: 'job="prometheus-operator"',
      },
    },
  },
  blackboxExporter+: {
    // Using only HTTP module
    modules: {
      http_2xx: {
        http: {
          preferred_ip_protocol: 'ip4',
        },
        prober: 'http',
      },
    },
    resources: {
      requests: { cpu: '30m', memory: '16Mi' },
      limits: { cpu: '64m', memory: '42Mi' },
    },
    replicas: 2,
    probes: {
      promDemo: {
        staticConfig: {
          static: [
            'https://demo.do.prometheus.io',
            'https://prometheus.demo.do.prometheus.io/-/healthy',
            'https://alertmanager.demo.do.prometheus.io/-/healthy',
            'https://node.demo.do.prometheus.io',
            'https://grafana.demo.do.prometheus.io/api/health',
          ],
          labels: { environment: 'prometheus.io' },
        },
      },
      thaumSites: {
        staticConfig: {
          static: [
            'https://weirdo.blog/ghost',
            'https://alchemyof.it/ghost',
            'https://zmc.krupa.net.pl',
          ],
          labels: { environment: 'thaum.xyz' },
        },
      },
      ingress: {
        ingress: {
          selector: {
            matchLabels: {
              probe: 'enabled',
            },
          },
          namespaceSelector: { any: true },
        },
      },
    },
  },
  kubernetesControlPlane+: {
    mixin+: {
      _config+: {
        // k3s exposes all this data under single endpoint and those can be obtained via "kubelet" Service
        kubeSchedulerSelector: 'job="kubelet"',
        kubeControllerManagerSelector: 'job="kubelet"',
        kubeApiserverSelector: 'job="kubelet"',
        cpuThrottlingPercent: 70,
      },
    },
  },
  grafana+: {
    version: '7.5.3',
    //image: 'grafana/grafana:7.5.3', // This is overridden in grafana-overrides.libsonnet
    datasources: [{
      name: 'Prometheus',
      type: 'prometheus',
      access: 'proxy',
      orgId: 1,
      isDefault: true,
      url: 'http://prometheus-k8s.monitoring.svc:9090',
    }],
  },
  // Following are not in kube-prometheus
  kubeEventsExporter: {
    namespace: 'monitoring',
    version: '0.1.0',  // application-version-from-github: rhobs/kube-events-exporter
    image: 'quay.io/dgrisonnet/kube-events-exporter:v0.1.0',  // application-image-from-github: rhobs/kube-events-exporter
    resources: {
      requests: { cpu: '2m', memory: '16Mi' },
    },
    commonLabels+: {
      'app.kubernetes.io/component': 'exporter',
    },
  },
  pushgateway: {
    namespace: 'monitoring',
    version: '1.4.1',  // application-version-from-github: prometheus/pushgateway
    image: 'quay.io/prometheus/pushgateway:v1.4.1',  // application-image-from-github: prometheus/pushgateway
    resources: {
      requests: { cpu: '10m', memory: '12Mi' },
    },
  },
  smokeping: {
    name: 'smokeping',
    namespace: 'monitoring',
    version: '0.4.2',  // application-version-from-github: SuperQ/smokeping_prober
    image: 'quay.io/superq/smokeping-prober:v0.4.2',  // application-image-from-github: SuperQ/smokeping_prober
    port: 9374,
    resources: {
      requests: { cpu: '40m', memory: '30Mi' },
      limits: { memory: '70Mi' },
    },
    replicas: 2,
    args: [
      '8.8.8.8',
      '1.1.1.1',
      'lancre.thaum.xyz',
      'krupa.net.pl',
      'cloud.krupa.net.pl',
      'pawel.krupa.net.pl',
    ],
  },
  pagespeed: {
    name: 'pagespeed',
    namespace: 'monitoring',
    version: 'latest',
    image: 'foomo/pagespeed_exporter',
    resources: {
      requests: { cpu: '10m', memory: '13Mi' },
      limits: { memory: '30Mi' },
    },
    sites: [
      'prometheus.io',
    ],
  },
  uptimerobot: {
    name: 'uptimerobot-exporter',
    namespace: 'monitoring',
    version: 'latest',
    image: 'quay.io/paulfantom/uptimerobot:latest',
    resources: {
      requests: { cpu: '10m', memory: '13Mi' },
      limits: { memory: '30Mi' },
    },
    port: 9705,
    secretRefName: 'uptimerobot-api-key',
    encryptedApiKey: 'AgC4xmdacpwqLMindlipAJDG3UhLuytkYmv7DU1PrNwfexpJwrp8Fp8CyHhz/4YPY00gHxc51oFCWSnfUzlcXn4a3sR+2srMr1GAl1SWUWszG2pO1jyXWiGhB6HrvfAWs3LeunQJCaTYuCoUvQ7zHtRIbK0AQEgQpG3Lkj9cH7Gu022ZSBvIeoz07h4pNL1fEF53TOE2gFs6U0d3q0nzgp2UK9XWcfmr27MafHGsImzfPM7UZKKHzRzvoWE2Q2R9uAushoG17An72TPHbGUtUzjxxjcOMi6/JjtZOhWhtx2LD3touBudqTFK9oDTpGH7ObU85FQX8NxiySMJ3faLkzGkGjv2zmLdgwxjQ3pbTJPJtRILpbCfiCF+qT2aKpp9pGcUAcsB14zLohGFFoayvXn91Bgyfh8/RmE5+3sZW1zOprsFe2TMZPF1Mkl0EpuE5qV0dzBC6TL6zPODDMjwjFNKP2f7spmrw5lULmPU4tKA2hb4zFvAW628fpXsqAtrhSU7NUrwlF2kktt5wiUK1WkSuZuM1FPuHWFE3G6t6DOC4ZUh0DdeQvUnR1947SIVzitVbrtUTrqvTTfrbb/2/A+nhPUU5VbR5J6VJCiJEjvSFHmUlxCft6+Vxe6Ypx2VlQWQo4SARrhgq11zhcZ/+CalvIb0BW+QFj2yGEORq68ThUuxdxbCERoIp8gVyQ+au32AbW5gdrQ+rDGXSNsN6McbDUWfMi30LuGe5TZNJDobVneR',
  },
  sloth: {
    name: 'sloth',
    namespace: 'monitoring',
    version: '0.3.1',
    image: 'slok/sloth:v0.3.1',
  },

  other: {},
}