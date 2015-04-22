# memcache-release

This Bosh release is meant to provide a fully featured Cloud fiendly Memcached compatible Service to a Cloud Foundry deployment.  This service was designed with ease of operational management, high scalability, and fault tolerance as its primary goals.

Features:
* Fully Binary Memcached protocol compatible
	* Including CAS
    * Supports any client that supports binary and SASL plain authentication
* Highly Available, spreads backups across zones
* Horizontally Scalable
* Multi-Tenant vis SASL auth
* Bosh Deployable
* CF Service Broker Provided
* Flexible Service Plans
* All Free and Open Source

## Deployment

The simplest way to deploy this memcache service is to use BOSH.  The following is an example of the properties section of a deployment manifest.

```
  domain: cf-deployment.com # Domain the broker and memcache-hazelcast will bind their http endpoints to
  nats: # Nats config needed to register with router.
    machines:
    - 10.10.100.10
    password: password
    port: 4222
    user: nats
    
  networks:
    apps: default
    management: default
  
  memcache_broker:
    broker_password: brokerpasswordforcc
    memcache:
      vip: 10.100.100.100:11211 # Optional ViP externally configured for simplified access to cluster
      servers: # List of all memcache-hazelcast instances in the cluster for client credentials
      - 10.100.100.101:11211
      - 10.100.100.102:11211
    plans:
      small:
        name: small
        description: A small cache with no redundency
        free: true

  memcache_hazelcast:
    heap_size: 512M # The Xmx value of the node's jvm
    host:
      srv_api: https://memcache-hazelcast.cf-deployment.com # Http endpoint for broker to interact with cluster (delete a cache, etc.)
      password: password # srv api password
    memcache:
      secret_key: secret # Secret Key broker and memcache-hazelcast share for password hashing
    hazelcast:
      max_cache_size: 268435456 # Max heap to reserve for cache data before forced eviction take place to protect against OOMErrors
      machines: #List all members of the cluster and their respective zones for backup distribution
        zone1:
        - 10.100.100.101
        zone2:
        - 10.100.100.102
    plans:
      small: # must match the plans.name in broker to associate the 2.
        backup: 0 # How many backups of entries to distribute accross the cluster
        async_backup: 1 # Same as above but done asyncronously
        eviction_policy: LRU #When plan reaches max quota how do we evict?
        max_idle_seconds: 86400 #Do we put a max ttl on data to help improve Over Commit abilities?
        max_size_used_heap: 100 #How much data including backups will this node hold. thisvalue*nodes=total quota
      medium: # must match the plans.name in broker to associate the 2.
        backup: 0 # How many backups of entries to distribute accross the cluster
        async_backup: 1 # Same as above but done asyncronously
        eviction_policy: LRU #When plan reaches max quota how do we evict?
        max_idle_seconds: 86400 #Do we put a max ttl on data to help improve Over Commit abilities?
        max_size_used_heap: 200 #How much data including backups will this node hold. thisvalue*nodes=total 
```

For more details on all of the config options available you can review the *spec* file for each of the jobs.

Once deployed simply register the service broker to the Cloud Controller and you should be good to go.

```
cf create-service-broker memcache servicebroker brokerpasswordforcc https://memcache-service.cf-deployment.com

cf enable-service-access memcache
```

Be sure to configure your bosh manifest to only deploy one node at a time giving hazelcast time to recover and repartition after each node is reset.

```
update:
  canaries: 1
  canary_watch_time: 3000-240000
  update_watch_time: 3000-240000
  max_in_flight: 1 # This is the important setting
```

### Memory Configuration
For a caching service it is important to configure memory correctly.  There are 3 places memory is configured that you should take note of:

#### memcache_hazelcast.heap_size
This value is passed directly to the JVM and represents the total heap this node should use.  -Xmx and -Xms are set to the same value since memory consumption and control of that memory consumption is the point of a cache node.

This value should be close to the total amount of RAM provided on the VM the job is deployed to.  Perhaps subtract 128M-384M or so for OS overhead and misc Java native memory consumption.

#### memcache_hazelcast.hazelcast.max_cache_size
This value represents the total amount of heap memcache-hazelcast should reserve for cache storage.  If the total memory cost of all the cache entries stored on this server exceed this value then the node will start evicting a percentage of owned entries on this node from each of the caches on this node.  This process doesn't care if the cache is large or small it just trims X% of the LRU entries from all of the caches to help relieve memory pressures on the node.

In a perfect world a node's memory pressures should never reach this point.  Operators should monitor cache size and increase the cache memory pool when cached memory reaches a certain threshold.

This value should obviously be less than heap_size.  The difference between max_cache_size and heap_size is the memory reserved for the node to actually operate, handle requests, and allow hazelcast to manage the cluster.  At a minimum this difference should probably be at least 256M.  The max will depend upon the amount of concurrent load you expect to get on each of the nodes.  We configure ours with a difference of 512M.

#### memcache_hazelcast.plans.{plan}.max_size_used_heap
This value is set in each of the plans you offer and represent the cache data in MB you wish this plan to allow on each of the nodes.  This value multiplied by the number of nodes deployed is the quota for this plan.  If I deploy 10 nodes and each have a max_size_used_heap of 100 then each service instance of this plan will have a quota of 1000MB.

This value includes backup data use.  So, if I have a backup of 1 you can cut the quota in half and that will represent the amount unique data this plan will hold.  A value of 100MB would represent roughly 50MB of unique cache data this node will hold for each service instance.

You can obviously play with these values and the naming of the plans all you want by adding more resiliancy vs. cache size.


### Example VCAP_SERVICES credentials
When the service is bound credentials similar to these will be provided to the app.

```
{
 "VCAP_SERVICES": {
  "memcache": [
   {
    "credentials": {
     "password": "securehashofusernameandsecretkey",
     "servers": [
      "10.10.100.40:11211",
      "10.10.100.41:11211",
      "10.10.100.42:11211",
      "10.10.100.43:11211",
      "10.10.100.44:11211",
      "10.10.101.40:11211",
      "10.10.101.41:11211",
      "10.10.101.42:11211",
      "10.10.101.43:11211",
      "10.10.101.44:11211"
     ],
     "username": "large|{service_instance_guid}|{app_guid}",
     "vip": "memcache-hazelcast.cf-deployment.com:11211"
    },
    "label": "memcache",
    "name": "large-memcache",
    "plan": "large",
    "tags": []
   }
  ]
 }
```

It is recommended that clients connect to all servers in the cluster and use a consistent hash to pseudo load balance between the nodes even though any key could actually be obtained from any node.  The vip (if configured) should only be used for cases where client config simplisity is desired over performance.


## Architecture Overview and Decision Process

When tasked with providing a caching solution for our organization we were given several requirments:
* Must be on premise to our datacenter
* Must support a wide variety of clients: Java, Node, Ruby, Python, etc.
* 100% up-time both the service and the data placed into the service
* Must work will with our organization's typical need of 100s of small to medium sized projects/clients
* Must be simple to operate:
	* Must be multi-tenant
	* No complex IaaS integration to provision/deprovision server(s) for each service instance
	* Limited to no customer coordination for scheduled maintanence (just like a 100% up SaaS solution)
* Must be able to grow horizontally to meet new demand without downtime
* Must perform adequately given the other constraints
* Must be multi-tenant with data not accesible between tenants
	* Nice if we could ahare a large memory pool to over commit accross all clients
	* Each tenant should be constrained by a memory quotas

### Evaluating Redis and Memcached
When you think of caching solutions with broad client support the 2 products that immediatly come to mind are Redis and Memcached.

The first solutions we investigated were Redis based.  However, open source Redis out of the box didn't appear to have any good multi-tenancy support.  Clustering for Redis 2 was also based on complex Master/Slave config and coordination which violated our easy to operate constraints.  Redis 3 was recently released that is supposed to provide better clustering support but we completed our evaluation prior to Redis 3 release.  Redis also brings some *nice to have* features like persistence and pub/sub.  But, these were not significant requirments for us.

We also investigated raw Memcached.  The main Memcached implementation is also not clusterable or multi-tenant.  With Memcached most clients support using a consistent hash to spread data across many memcached instances causing limited loss of data in the case of an outage but would not fulfil the zero down time requirment for scheduled maintanence.  Multi-tenancy requirements would require us to either write a proxy or manage independent memcached process(s) for each customer.

There are thirdparty vendors that provide multi-tenancy and cluster management capabilities on top of Redis and Memcached but these solutions were typically too expensive for us to consider at this point.

### In-Memory Data Grid Evaluation
During the process of evaluating Memcached we discovered that there are many distributed caching solutions on the market that provided Memcached server compatibilities.  Many of these solutions were Java based and were Free and/or Open Source.  None of these clusterable thirdparty memcache solutions provided a multi-tenant memcache implementation but they otherwise fulfilled most all of our given requirements and all of them were emeddable.  So, it was decided we would select a Java memory grid solution and embed with a multi-tenant memcache compabible front end that we would write. 

We evaluated [Infinispan], [Hazelcast], [Gemfire], and [GridGain].  Of the solutions evaluated Hazelcast is the solution we selected for the following reasons:
* Fully Open Source
* Simple to use heap usage based quotas that matched our needs well
* Fully async under the hood simplifying operations such as thread pool sizing
* Single purpose simple In-Memory data grid not a solution tring to be everything to everyone
* An affordable non-usage based licensing program we could purchase if it is determined we need a support contract
* Mechanisms to efficiently work with large byte arrays without costly memory copies
* Large very active and happy community

[Hazelcast]: http://hazelcast.org/
[Infinispan]: http://infinispan.org/
[GridGain]: http://www.gridgain.com/
[Gemfire]: http://projectgeode.org/

#### A word about Gemfire/Project Geode
With the announcement of Gemfire being open sourced it quickly jumped to the top of our list.  We had a *nice to have* desires for persistence/overflow to disk and an obvious affinity for Pivotal projects.  However it was ultimatly not selected because:
* Customer was dictating a tight timeline that didn't allow us to wait for Project Geode
* Gemfire's memory quota eviction wasn't as straight forward and rigid as Hazelcast's when evaluated
* Multi datacenter support was another *nice to have* that was not open sourced with geode

If Project Geode were to add more clear in-memory quotas and/or open source multi-datacenter support we would seriously consider migrating to it.

#### Netty Memcache Codec
Netty recently added a Memcache Codec to its 4.1.0 release.  Consiquently use of Netty for our highly scalable and efficient front end was a no brainer and has worked out quite well.

### Architecture Details
Here are a few notes of the basic architecture of the memcache-broker, memcache-hazelcast, and how they work together.

#### memcache-hazelcast

This is the module that acts as the memcache front-end and a Hazelcast node member.  All memcache requests come to a memcache-hazelcast node and is asynchronously executed on the node actually owning the key being operated on using an *IExecutorService*.  This allows a single memcache connection to process many pipelined requests at once.  The responses to these requests are then sorted and returned to the client in the order requested.

Using hazelcast synchronously was actually slightly quicker from a single request latency standpoint.  However, the asyncronous solution was significantly much more scalable and the difference was neglible when including network latencies. 

By executing the request on the node that owns the key it ensures that every single memcache request will only include at most one network hop for actual processing of the request.  This is important since some memcache requests result in several Hazelcast operations.  For example, the an increment consists of 4 commands lock, get, set, and unlock.  By running on the node that owns the key no blocking for network communication occurs for any of these operations. 

We hope to eventually provide an option to take advantage of Hazelcast's *Near-Cache* functionality.  When combined with a good consistent hashing algorithm data frequently returned form *get* requests would often require no additional network hop at all.  However, we found a minor [issue] with Hazelcast delaying this functionality.

[issue]: https://github.com/hazelcast/hazelcast/issues/5133

#### memcache-broker
This module provides a Cloud Foundry v2 Service Broker.  Allowing users to create, bind, unbind, delete cache tenants for Cloud Foundry deployed apps.  The broker is stateless and therefore clusterable.

#### Authentication
Authentication is implemented as a hash using a shared key between the memcache-broker and memcache-hazelcast nodes.  This solution was chosen in an attempt to eliminate the need to deploy and manage a persistent credentials store of some sort.  The main limitation with this solution is to rotate a cache password the user would to create and bind to a new Service Instance this would essentially invalidate the old password and give them a new password for a new cache.

#### Performance
We have not performed extensive performance tests on this solution though we have done some scalability testing.  The tests we have run shows that memcache-hazelcast uses quite a bit more CPU than raw Memcached.

We have profiled memcache-hazelcast and believe the solution is quite efficient as a front end to hazelcast.

As far as latency goes under a single thread localhost to localhost not clustered test the mean request time for memcache-hazelcast appeared to be about 2-3 times worse than memcached (350000 vs 150000) nanoseconds.  When placed under siginifcant load (1000+ threads) mean times between memcache-hazelcast and raw memcached actually began to match.

We haven't run any real network tests comparing memcache-hazelcast with memcached only localhost test.

So it is obvious that Hazelcast, as a more complex memory grid solution, is slower than raw Memcached no big suprise there.  But, it appears as though it will perform well enough for our requirements and perhaps yours too?

## FAQ
### Why are you using Memcache and not Redis?  Don't you know Redis is the best?
Though I don't have much development experience with either Memcached or Redis, I have no doubt that Redis is superior to Memcached in many ways.  However, raw Redis just didn't meet what we were looking to provide regarding multi-tenancy and Redis 2 lacked clustering.  We looked into potentially fronting Hazelcast with a Redis like protocol instead of Memcache but the protocol and command set appears far more rich and complex than Memcache's protocol making fronting Hazelcast with a Redis protocol not feesible.

### Why use Memcache at all?  Why not use raw Hazelcast or some custom protocol?
In addition to the abundant client support for the Memcache protocol we liked the idea of giving our customers a semi stable and simple Memcache API to depend upon instead of something custom or more nitch.  This gives our customers who depend upon the Memcache Protocol more API stability and allows us to potentially change solution details in the future without asking all our customers to rewrite their cache logic.

Using the Memcache protocol also allows our customers to potentially utilize a thirdparty Clustered Memcache SaaS solution for amazon vs. on prem deployments without changing their application.

### Is this project so bad that you're planning to migrate off of it already?
No, we're quite proud of this project.  But we recognize that our organization's requirements for a cache solution may change.  We also know that our solution may not be the fastest or best available.  So, we plan to use this solution for as long as it meets our needs and hope to minimize impact to users of this service if things change in the future.

### Memory Management in Java is hard and error prone.  How do you mitigate the risk of Java OOMErrors?
It is true, Java's abstraction over how it manages memory makes it hard to implement something like a multi tenant memory quota based cache.  Under periods of heavy load an over-committed cache cluster could cause a node to run out of memory and fail.  This could potentially bringing down the entire cluster as backups are re-replicated and new owners for the data is established.

This potential issue has been on the forfront of our minds from the beginning and believe our solution is fairly safe.  First of all Hazelcast provides a great foundation for memory based quotas in a multi tenant cache.  Hazelcast eviction config is on a per node basis not for the entire cluster.  So, if a node goes down each cache on the other nodes won't attempt to allow more memory for a cache than that node's share of the quota allows.  This protects the whole cluster as backups are re-replicated and new owners are identified if a single node's cache quota is exceeded Hazelcast will start evicting.

The Hazelcast config above should work perfectly if you are not over committing your cluster.  However, we are big fans of over committing our resources for greater pooled resource efficiency in our system.  So, we implemented a system allowing the deployer to reserve a maximum amount of memory for cache data.  If suddenly a cache node's cache data exceedes this reserve maximum a scheduled job will LRU evict X percent of the owned entries on each of the caches on that node relieving memory pressures.  This job will also log angry messages warning you that you need to add more nodes or memory to your cluster ASAP to further prevent customer data from being unexpectedly evicted.  However, in a perfect world a good operator of an overcommitted cluster would pay attention to the metrics being emitted from the nodes and add more capacity prior to this last resort safety measure having to kick in.

### How compatible is this service with real Memcached?
We believe it to be very compatible.  We have an integration that continuously runs [memcapable] against our server.  We have other integration tests to regress functionality not covered by [memcapable] like GAT and touch.

This service supports CAS.  Something that seems many non-memcached implementations seem to leave out for some reason.

The implementation has been tested with several clients notable libmemcached, spymemcached, and xmemcached.  All seem to work well.

That said we're pretty new to Memcache and we may have completely misread the spec in relation to certain functions.  If you find we messed something up please file an issue.

[memcapable]: http://libmemcached.org/Memcapable.html