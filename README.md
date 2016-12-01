instance_groups:
-name: memcache_broker
jobs:
  - name: route_registrar
    release: cf
  - name: memcache_broker
    release: memcache
properties:
  route_registrar:
    routes:
    - name: memcache_broker
      port: 21080
      registration_interval: 20s
      uris:
      - memcache-service.cf-deployment.com
    host:
      port: 21080
  memcache_hazelcast:
    host:
      srv_api: https://memcache-hazelcast.cf-deployment.com
      password: password
    memcache:
      secret_key: secret
-name: memcache
  update:
    max_in_flight: 1
  jobs:
  - name: metron_agent
    release: cf
  - name: route_registrar
    release: cf
  - name: memcache_hazelcast
    release: memcache
properties:
  route_registrar:
    routes:
    - name: memcache_hazelcast
      port: 8080
      registration_interval: 20s
      uris:
      - memcache-hazelcast.cf-deployment.com
      port: 8080
      srv_api: https://memcache-hazelcast.cf-deployment.com # Http endpoint for broker to interact with cluster (delete a cache, etc.)
      test_password: password
      test_cache: test
      test:
        backup: 0
        async_backup: 0
        eviction_policy: LRU
        max_idle_seconds: 60
        max_size_used_heap: 1
The latest version of this service has been tested with ubuntu-trusty version 3232.12.  It will probably work fine for all newer version too.  The recent upgrade to Kernel 4.4 in ubuntu might be the only significant thing with that stemcell.
Currently memcache-hazelcast and memcache-broker produces useful metrics sent over the firehose.  Support for metrics over varz/healthz was recently removed.
Netty recently added a Memcache Codec to its 4.1.0 release.  Consequently use of Netty for a highly scalable and efficient front end was a no brainer and has worked out quite well.