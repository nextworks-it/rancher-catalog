version: '2'
services:

# ----------
# SUPERVISOR
# ----------

  nxw-sv:
    privileged: true
    security_opt:
      - seccomp:unconfined
    image: docker-registry.nextworks.it/nxw-sv:2.3.45-1
    restart: on-failure
    stdin_open: true
    network_mode: host
    hostname: supervisor
    depends_on:
      - fluent-bit
    volumes:
      - bundle-manager-share:/usr/share/bundle-man:ro
      - /dev:/dev:rw
      - nxw-sv-hermes:/hermes
      - nxw-sv-data:/mnt/data
      - nxw-sv-logs:/var/log
      # the following are used as upperdir and workdir
      # to overlay mount the related image dirs
      - nxw-sv-persistance:/persistance
      - nxw-sv-www-remotes:/var/www/localhost/htdocs/remotes
      - nxw-sv-root-persistent:/root/persistent
      - logs:/var/log/old_containers
      - container-logs:/var/log/containers:rw
      - data-console-persistence:/var/lib/nxw-console
      - nxw-sv-etcd-run:/hermes/etcd.d
      - nxw-sv-etcd-state:/var/lib/etcd
    tty: true
    # The entrypoint sets network defaults
    # and other initial setups to prepare the container environment
    entrypoint: /entrypoint.sh
    stop_grace_period: 1m30s
    stop_signal: SIGINT
    labels:
      io.rancher.container.dns: 'true'
      io.rancher.container.network: 'true'
      #io.rancher.container.pull_image: always
      it.nextworks.dependencies: "oamd >= v1.6.10, oamd < v2.0.0-1"
    environment:
      - PYTHONPATH=/opt/hermes/lib/python
      - OAMD_SERVICE_HOST=oamd.oamd.rancher.internal
      - OAMD_SERVICE_PORT=54567

      - ETCD_SERVICE_HOST=nxw-etcd
      - ETCD_SERVICE_PORT=2379

      - OSRD_SERVICE_HOST=osrd.external
      - OSRD_SERVICE_PORT=8345

      - GUMON_AM_DISABLED=True
      - GUMON_CHMGR_DISABLED=True
      - GUMON_PLINSKY_DISABLED=True
      - GUMON_FVSTORAGE_DISABLED=True
      - GUMON_UHAL_DISABLED=True
      - GUMON_LM_DISABLED=True
      - GUMON_SPACFG_DISABLED=True
      - GUMON_SEM_DISABLED=True
      - GUMON_TMS_DISABLED=True
      - GUMON_AIS_DISABLED=True
      - GUMON_POSD_DISABLED=True
      - GUMON_ETCD_DISABLED=True

      - LICENSE_MANAGER_SERVICE_HOST=license-manager
      - LICENSE_MANAGER_SERVICE_QPORT=5001
      - LICENSE_MANAGER_SERVICE_SPORT=5000
      - LICENSE_MANAGER_SERVICE_RPORT=5002

      - ALARM_MANAGER_SERVICE_HOST=alarm-manager
      - ALARM_MANAGER_SERVICE_PORT=8085

      - CHANNEL_MANAGER_SERVICE_HOST=channel-manager
      - CHANNEL_MANAGER_SERVICE_PORT1=6980
      - CHANNEL_MANAGER_SERVICE_PORT2=9080

      - PLINSKY_SERVICE_HOST=plinsky
      - PLINSKY_SERVICE_PORT=50051

      - BUNDLE_MANAGER_SERVICE_HOST=bundle-manager
      - BUNDLE_MANAGER_SERVICE_PORT=8345

      - BUNDLE_DESCRIPTOR=/usr/share/bundle-man/bundle.json

      - TEX_SERVICE_HOST=tex-server
      - TEX_SERVICE_PORT=11051

      - FVS_IEM_FVSTORAGE_HOST=fvstorage

      - DB_ADMIN=db_admin
      - DB_ADMIN_PASSWORD=YjVhYWI5ZjZhNzYx

      - ENABLE_DHCP=${ENABLE_DHCP}

      - CONSOLE_DEFAULT_STACK=nxw-sv
      - CONSOLE_PERSISTENCE=/var/lib/nxw-console

      - RABBITMQ_SERVICE_HOST=rabbit.external
      - RABBITMQ_SERVICE_PORT=5672
      - RABBITMQ_SERVICE_MQTT_PORT=1883

      - JANITOR_SERVICE_HOST=janitor
      - JANITOR_SERVICE_GRPC_PORT=8345
      - JANITOR_SERVICE_REST_PORT=8346
      - GRPC_DNS_RESOLVER=native

      #- NAVDATA_SERVICE_HOST=nxw-sv.external
      #- NAVDATA_SERVICE_GRPC_PORT=7000
      #- NAVDATA_SERVICE_REST_PORT=7001

# ----------
# JANITOR
# ----------

  janitor:
    privileged: true
    image: docker-registry.nextworks.it/janitor:v0.0.5
    environment:
      - CLEAN_PERIOD=3600
      - KEEP_CONTAINERS=*:*
      - KEEP_CONTAINERS_NAMED=*-datavolume, *nxw-sv*
      - KEEP_IMAGES=rancher/
      - DOCKER_API_VERSION=1.21
      - GRPC_DNS_RESOLVER=native
    network_mode: managed
    depends_on:
      - fluent-bit
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker:/var/lib/docker
    labels:
      io.rancher.scheduler.affinity:host_label_ne: janitor.exclude=true
      io.rancher.scheduler.global: 'true'
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "janitor"
        syslog-format: "rfc5424"

# ----------
# RABBITMQ
# ----------

  rabbitmq:
    image: "docker-registry.nextworks.it/rabbitmq:rabbitmq-server_v3.11-v0.0.3"
    restart: on-failure
    #ports:
    #  - '5672:5672'
    #  - '1883:1883'
    #  - '15672:15672'
    network_mode: host
    dns: 127.0.0.1
    environment:
      - RABBITMQ_DEFAULT_USER=guest
      - RABBITMQ_DEFAULT_PASS=guest
      - RABBITMQ_DEFAULT_VHOST=/
      - GRPC_DNS_RESOLVER=native
    volumes:
      - rabbitmq-data-volume:/var/lib/rabbitmq:rw
      - rabbitmq-init:/etc/rabbitmq
    depends_on:
      - rabbitmq-data
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "rabbitmq"
        syslog-format: "rfc5424"

  rabbitmq-data:
    image: "docker-registry.nextworks.it/rabbitmq-data:rabbitmq-server_v3.11-v0.0.3"
    restart: on-failure
    volumes:
      - rabbitmq-init:/etc/rabbitmq
    labels:
      io.rancher.container.start_once: true
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "rabbitmq-data"
        syslog-format: "rfc5424"

# ----------
# PANEL FACTORY BE
# ----------

  panels-factory-be:
    image: docker-registry.nextworks.it/panels-factory-be:v2.0.11
    restart: on-failure
    network_mode: managed
    ports:
      - '7110:7110/tcp'
    environment:
      - ETCD_SERVICE_HOST=nxw-etcd
      - ETCD_SERVICE_PORT=2379
      - REDIS_SERVICE_HOST=nxw-sv
      - REDIS_SERVICE_PORT=6379
      - NAMING_HOST=nxw-sv
      - NAMING_PORT=6900
      - GRPC_DNS_RESOLVER=native
    volumes:
      - nxw-sv-www-remotes:/var/www/localhost/htdocs/remotes:rw
      - nxw-sv-hermes:/mnt/nxw-sv/run:ro
    depends_on:
      - nxw-sv
      - fluent-bit
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "panels-factory-be"
        syslog-format: "rfc5424"
    #labels:
    #  io.rancher.container.pull_image: always

# ----------
# RESTIFIER
# ----------

  restifier:
    image: docker-registry.nextworks.it/restifier:v1.0.2
    restart: on-failure
    network_mode: managed
    environment:
      ETCD_SERVICE_HOST: nxw-etcd
      ETCD_SERVICE_PORT: '2379'
      RESTIFIER_PORT: '4995'
      GWREMOTE_HOST: nxw-sv
      GWREMOTE_PORT: '6901'
      SEM_SERVICE_HOST: sem
      SEM_SERVICE_PROTOCOL_PORT: '12346'
      TMS_SERVICE_HOST: tms
      TMS_SERVICE_PROTOCOL_PORT: '12366'
      AIS_SERVICE_HOST: ais
      AIS_SERVICE_PROTOCOL_PORT: '12356'
      RABBITMQ_SERVICE_HOST: rabbitmq
      RABBITMQ_SERVICE_PORT: '5672'
      RABBITMQ_EXCHANGE: 'restifer'
      LOGS_LEVEL: info
      GRPC_DNS_RESOLVER: native
    volumes:
      - nxw-sv-data:/opt/src/restifer/tmp
    ports:
      - 4995:4995/tcp
    labels:
      io.rancher.container.pull_image: always
    depends_on:
      - fluent-bit
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "restifier"
        syslog-format: "rfc5424"

# ----------
# BUNDLE MANAGER
# ----------

  bundle-manager:
    image: docker-registry.nextworks.it/bundle-manager:v0.3.8
    restart: on-failure
    network_mode: managed
    #ports:
    #  - "8345:8345"
    environment:
      - ETCD_SERVICE_HOST=nxw-etcd
      - ETCD_SERVICE_PORT=2379
      - LOGS_LEVEL=info
      - GRPC_DNS_RESOLVER=native
    volumes:
      - bundle-manager-share:/usr/share/bundle-man/share
      - bundle-manager-state:/var/lib/bundle-man/state
    depends_on:
      - fluent-bit
      - nxw-sv
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "bundle-manager"
        syslog-format: "rfc5424"

# ----------
# SIABOT
# ----------

  siabot:
    image: docker-registry.nextworks.it/siabot:v0.7.8
    # siabot networking is managed and it needs to access the rabbit-mq server
    # which is into the legacy supervisor at the moment. The env var
    # RABBITMQ_SERVICE_HOST set to rabbit.external and dns set to 127.0.0.1
    # wouldn't help since its and host' loopbacks wouldn't overlap and thus
    # siabot wouldn't be able to resolve rabbit.external from dnrd. We need to
    # directly point to the legacy stack to solve the problem
    environment:
      - OSR_ENABLE=true
      - BUNDLE_DESCRIPTOR=/bundle/bundle.json
      - SIABOT_SERVICE_HOST=siabot
      - SIABOT_SERVICE_PORT=5666
      - DYNAMO_ENABLE=false
      - ETCD_SERVICE_HOST=nxw-etcd
      - ETCD_SERVICE_PORT=2379
      - MONGODB_SERVICE_HOST=mongodb
      - MONGODB_SERVICE_PORT=27017
      - RABBITMQ_SERVICE_HOST=rabbitmq
      - RABBITMQ_SERVICE_PORT=5672
      - TEX_SERVICE_HOST=tex-server
      - TEX_SERVICE_PORT=11051
      - PROTOCOL_ENABLE=true
      - NAMING_HOST=nxw-sv
      - TZ_SERVICE_HOST=nxw-sv
      - TZ_SERVICE_PORT=9001
      - SCENARIO_ENABLE=true
      - SCENARIO_SERVICE_HOST=nxw-sv
      - GRPC_DNS_RESOLVER=native
    restart: on-failure
    network_mode: managed
    ports:
      - "5666:5666/tcp"
    volumes:
      - bundle-manager-share:/bundle:ro
    depends_on:
      - fluent-bit
      - mongodb
      - nxw-sv
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "siabot"
        syslog-format: "rfc5424"

# ----------
# PLINSKY
# ----------

  fuseki:
    image: "docker-registry.nextworks.it/fuseki:v4.3.1"
    restart: on-failure
    network_mode: managed
    #ports:
    #  - "3030:3030"
    volumes:
      - data-plinsky-fuseki:/var/lib/apache-jena-fuseki
    depends_on:
      - fluent-bit
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "fuseki"
        syslog-format: "rfc5424"

  plinsky:
    image: "docker-registry.nextworks.it/plinsky:v0.4.31"
    restart: on-failure
    network_mode: host
    # dns points to dnrd on nxw-sv, which runs in network nost mode
    dns: 127.0.0.1
    ports:
      - "50051:50051"
    volumes:
      - data-plinsky-fuseki:/var/lib/apache-jena-fuseki
      - bundle-manager-share:/mnt:ro
    depends_on:
      - fluent-bit
      - fuseki
    environment:
      - FUSEKI_SERVICE_HOST=fuseki
      - FUSEKI_SERVICE_PORT=3030
      - ETCD_SERVICE_HOST=nxw-etcd
      - ETCD_SERVICE_PORT=2379
      - EXTERNAL_IFACE=eth0
      - BUNDLE_DESCRIPTOR=/mnt/bundle.json
      - GRPC_DNS_RESOLVER=native
    entrypoint:
      - /usr/local/bin/plinsky
      - --fuseki_base_dir=/var/lib/apache-jena-fuseki/run
      - --workers=10
      - --reflection
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "plinsky"
        syslog-format: "rfc5424"

# ----------
# ALARM MANAGER
# ----------

  alarm-manager-datavolume:
    image: docker-registry.nextworks.it/alarm-manager-data:0.9.1-443-g839d8641
    network_mode: "none"
    labels:
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
      io.rancher.container.start_once: true
    volumes:
      - mongodbconf:/data/mongodb
    entrypoint: /bin/true

  alarm-manager:
    image: docker-registry.nextworks.it/alarm-manager:v0.20.6
    restart: on-failure
    network_mode: host
    # dns points to dnrd on nxw-sv, which runs in network nost mode
    dns: 127.0.0.1
    environment:
      - CONF_PATH=/etc/hermes/alarm_manager
      - DATA_PATH=/var/run/alarm_manager
      - AM_DEBUG_ENABLED=false
      - ALARM_MANAGER_SERVICE_HOST=alarm-manager
      - ETCD_SERVICE_HOST=nxw-etcd
      - ETCD_SERVICE_PORT=2379
      - MONGODB_SERVICE_HOST=mongodb
      - MONGODB_SERVICE_PORT=27017
      - RABBITMQ_SERVICE_HOST=rabbit.external
      - RABBITMQ_SERVICE_PORT=5672
      - ALARM_MANAGER_CLOUD_ENABLED=true
      - SYNC_ENABLED=true
      - ALARM_MANAGER_ACTIVE_FILTERS=true
      - MAINTENANCE_SERVICE_REST_PORT=8086
      - MAX_CONN_POOL_DB=20
      - DB_USE_ALWAYS_DISK_ON_QUERY=true
      - DB_MAX_RESULTS_ALLOWED=100000
      - MAX_USER_QUEUE_LENGTH=1000
      - EXPORT_MAX_BULK_ALARMS=10000
      - BUNDLE_DESCRIPTOR=/etc/hermes/alarm_manager/cloud/bundle.json
      - SYNC_ENABLED=false
      - SUBSCRIPTION_CHECK_TIME=300
      - DEBUG_REST_REQUESTS=false
      - DEBUG_REST_RESPONSES=false
      - OSR_DEBUG=false
      - GRPC_DNS_RESOLVER=native

    # Do it really need the following 'external_links' ?
    # external_links:
    #   - channel_manager
    privileged: yes
    # Do it really need the following 'devices' ?
    # devices:
    #   - /dev/:/dev/
    ports:
      # protocol port remapped
      - '8085:8085'
      - '8086:8086'
      - '8057:8057'
    volumes:
      - data-alarm-manager:/var/run/alarm_manager:rw
      - bundle-manager-share:/etc/hermes/alarm_manager/cloud:ro
    depends_on:
      - fluent-bit
      - mongodb
      - nxw-sv
      - conditions-gateway
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "alarm-manager"
        syslog-format: "rfc5424"

  mongodb:
    image: docker-registry.nextworks.it/mongo:4.4.4
    container_name: "mongodb"
    restart: on-failure
    environment:
      - MONGO_INITDB_DATABASE="alarm_manager"
    volumes:
      - mongodbconf:/docker-entrypoint-initdb.d/:ro
      - mongo-datavolume:/data/db:rw
    network_mode: managed
    #ports:
    #  - "27017:27017"
    #  - "27018:27018"
    #  - "27019:27019"
    depends_on:
      - fluent-bit
      - alarm-manager-datavolume
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "mongodb"
        syslog-format: "rfc5424"

  tex-server:
    image: docker-registry.nextworks.it/template-expander:v0.1.3
    restart: on-failure
    entrypoint: [ "/usr/local/bin/nxwtex", "--templ_dir", "/TEMPLATES" ]
    #command: [ "--port", "11051" ]
    #ports:
    #  - "11051:11051"
    environment:
      - PLINSKY_SERVICE_HOST=plinsky
      - PLINSKY_SERVICE_PORT=50051
      - TEX_SERVICE_PORT=11051
      - TZ_SERVICE_HOST=nxw-sv
      - TZ_SERVICE_PORT=9001
      - GRPC_DNS_RESOLVER=native
    # tex-server requires the console (nxw-sv) just to get the timezone and
    # plinsky for info resolution
    depends_on:
      - fluent-bit
      - nxw-sv
      - plinsky
    network_mode: managed
    volumes:
      - data-tex:/TEMPLATES:rw
    # DNS points to dnrd on nxw-sv.
    # Using the ipsec ip address "attached" to docker0 interface
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "template-expander"
        syslog-format: "rfc5424"

# ----------
# ANOMALY-MANAGER
# ----------
#
#  anomaly-manager:
#    image: docker-registry.nextworks.it/anomaly-manager:v0.1.1
#    restart: on-failure
#    environment:
#      - SQLALCHEMY_DATABASE_URI=sqlite:////data/anomalymanager.sqlite
#      - JSON_DATASOURCE_URL=http://localhost:6996/api/v1/grafana/
#      - DATA_DIR=/data
#      # EVENTS DB
#      - DBEVENTS_port=5432
#      - DBEVENTS_user=supervisor
#      - DBEVENTS_password=supervisor
#      - DBEVENTS_host=nxw-sv
#      - DBEVENTS_database=supervisor
#      # RABBIT
#      - RABBIT_user=guest
#      - RABBIT_password=guest
#      - RABBIT_host=rabbit.external
#      - RABBIT_port=5672
#      - RABBIT_exchange=EVENT_EXCHANGE
#      - RABBIT_topic=event.generic.anomaly
#      # Undefine DISABLED if you want the Anomaly Manager enabled
#      - DISABLED=XXX
#    volumes:
#      - data-anomaly-manager:/data
#    network_mode: host
#    # dns points to dnrd on nxw-sv, which runs in network nost mode
#    dns: 127.0.0.1
##    ports:
##      - "4123:4123"
#    depends_on:
#      - nxw-sv
#    logging:
#      driver: syslog
#      options:
#        # Using the docker bridge address of host node
#        # to reach the supervisor.
#        # This is a trick which works since the supervisor container runs in
#        # 'host' networking mode, so the syslog running on supervisor is also
#        # reachable to such address.
#        syslog-address: udp://172.17.0.1:24224
#        tag: "anomaly-manager"
#        syslog-format: "rfc5424"

# ----------
# HTTP-MQTT
# ----------
# NOTE: Keep the following service name as 'mqtt' until SP-880 is fixed

  mqtt:
    image: docker-registry.nextworks.it/http-mqtt:v1.2.1
    restart: on-failure
    environment:
      - ETCD_SERVICE_HOST=nxw-etcd
      - ETCD_SERVICE_PORT=2379
      - SERVICES=alarm-manager:http://alarm-manager:8086,scenario-manager:http://nxw-sv:8910,supervisor-console:http://nxw-sv:80,analytic:http://analytic:8058
      - BUNDLE_DESCRIPTOR=/var/lib/bundle-man/bundle.json
      - LOGS_LEVEL=info
      - GRPC_DNS_RESOLVER=native
    volumes:
      - bundle-manager-share:/var/lib/bundle-man:ro
    network_mode: managed
    depends_on:
      - fluent-bit
    # DNS points to dnrd on nxw-sv.
    # Using the ipsec ip address "attached" to docker0 interface
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "http-mqtt"
        syslog-format: "rfc5424"

# ----------
# CONDITIONS-GATEWAY
# ----------

  conditions-gateway:
    image: docker-registry.nextworks.it/conditions-gateway:v0.1.0
    restart: on-failure
    network_mode: managed
    #ports:
    #  - '8001:8001'
    environment:
      - ETCD_SERVICE_HOST=nxw-etcd
      - ETCD_SERVICE_PORT=2379
      - CGW_SERVICE_HOST=conditions-gateway
      - CGW_SERVICE_PORT=8001
      - LOGS_LEVEL=info
      - GRPC_DNS_RESOLVER=native
    depends_on:
      - fluent-bit
      - nxw-sv
    # DNS points to dnrd on nxw-sv.
    # Using the ipsec ip address "attached" to docker0 interface
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "conditions-gateway"
        syslog-format: "rfc5424"

# ----------
# CHANNEL MANAGER
# ----------

  channel-manager:
    image: docker-registry.nextworks.it/channel-manager:v0.9.204
    restart: on-failure
    # DNS points to dnrd on nxw-sv.
    # Using the ipsec ip address "attached" to docker0 interface
    network_mode: managed
    #ports:
    #  - '9080:9080'
    dns: 127.0.0.1
    depends_on:
      - fluent-bit
    environment:
      - CHANNEL_MANAGER_SERVICE_HOST=channel-manager
      - ETCD_SERVICE_HOST=nxw-etcd
      - ETCD_SERVICE_PORT=2379
      - REDIS_SERVICE_HOST=nxw-sv
      - REDIS_SERVICE_PORT=6379
      - TEX_SERVICE_HOST=tex-server
      - TEX_SERVICE_PORT=11051
      - AM_CONNECTION_TIMEOUT=20
      - AM_CONNECTION_RETRY=3
      - GRPC_DNS_RESOLVER=native
    command:
      - channel-manager
    volumes:
      - data-channel-manager:/var/run/channel-manager:rw
      - nxw-sv-hermes:/hermes:ro
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "channel-manager"
        syslog-format: "rfc5424"

# --------------
# CHRONO MANAGER
# --------------

  chrono-manager:
    image: docker-registry.nextworks.it/chrono-manager:v1.0.3
    restart: on-failure
    #network_mode: managed (depends on SP-649)
    ports:
      - "12040:12040"
    network_mode: host
    dns: 127.0.0.1
    depends_on:
      - fluent-bit
      - nxw-sv
      - plinsky
    environment:
      - ETCD_SERVICE_HOST=nxw-etcd
      - ETCD_SERVICE_PORT=2379
      - OSRD_SERVICE_HOST=osrd.external
      - OSRD_SERVICE_PORT=8345
      - RABBITMQ_SERVICE_HOST=rabbit.external
      - RABBITMQ_SERVICE_PORT=5672
      - EXTERNAL_IFACE=eth0
      - TZ_SERVICE_HOST=nxw-sv
      - TZ_SERVICE_PORT=9001
      - REDIS_SERVICE_HOST=nxw-sv
      - REDIS_SERVICE_PORT=6379
      - REDIS_WEBSERVER_KEY=global.web_server
      - GRPC_DNS_RESOLVER=native
      #- NGINX_PREFIX=chronomanager
    volumes:
      - data-chrono-manager:/var/lib/chrono-manager
      - nxw-sv-hermes:/hermes:ro
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "chrono-manager"
        syslog-format: "rfc5424"

# ----------
# FVSTORAGE
# ----------

  fvstorage:
    image: docker-registry.nextworks.it/fvstorage:v1.2.114
    restart: on-failure
    network_mode: host
    # dns points to dnrd on nxw-sv, which runs in network nost mode
    dns: 127.0.0.1
    #ports:
    #  - '6968:6968'
    #  - '6996:6996'
    environment:
      #- FVSTORAGE_SERVICE_HOST=nxw-sv
      - EXTERNAL_IFACE=eth0
      - INITIAL_DATASTORE_NS_DSN=postgresql://fvstorage:fvstorage@nxw-sv/fvstorage_timeseries
      - FVSTORAGE_SERVICE_PORT=6996
      - FVSTORAGE_PROTOCOL_PORT=6968
      - INITIAL_DATASTORE_DSN=postgresql://fvstorage:fvstorage@nxw-sv/fvstorage_timeseries
      - NAMING_HOST=nxw-sv
      - NAMING_PORT=6900
      - ETCD_SERVICE_HOST=nxw-etcd
      - ETCD_SERVICE_PORT=2379
      - DB_ADMIN=db_admin
      - DB_ADMIN_PASSWORD=YjVhYWI5ZjZhNzYx
      - INITIALIZE_DB=True
      - GRPC_DNS_RESOLVER=native
    depends_on:
      - fluent-bit
      - nxw-sv
    volumes:
      - fvstorage-status:/status
      - fvstorage-exports:/exports
      - bundle-manager-share:/bundle
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "fvstorage"
        syslog-format: "rfc5424"

# --------
# ANALYTIC
# --------

  analytic:
    image: docker-registry.nextworks.it/analytic:v0.2.5
    restart: on-failure
    network_mode: managed
    #ports:
    #  - '8058:8058'
    environment:
      - ANALYTIC_SERVICE_HOST=analytic
      - ANALYTIC_SERVICE_PORT=8058
      - FVSTORAGE_HOST=nxw-sv
      - FVSTORAGE_PORT=6996
      - ETCD_SERVICE_HOST=nxw-etcd
      - ETCD_SERVICE_PORT=2379
      - AM_SCHEMA_PATH=/usr/local/lib/python3.9/site-packages/nxw/analytic/schemas/
      - GRPC_DNS_RESOLVER=native
    depends_on:
      - fluent-bit
      - nxw-sv
    volumes:
      - data-analytic:/var/lib/analytic
    # DNS points to dnrd on nxw-sv.
    # Using the ipsec ip address "attached" to docker0 interface
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "analytic"
        syslog-format: "rfc5424"

# --------
# FAVO
# --------

  favo:
    image: docker-registry.nextworks.it/favo:v0.35.7
    #hostname: favo
    environment:
      FAVO_SERVICE_HOST: favo
      ETCD_SERVICE_HOST: nxw-etcd
      ETCD_SERVICE_PORT: '2379'
      PPROF_ENABLED: 'false'
      LOGGER_LEVEL: INFO
      OSRD_SERVICE_HOST: nxw-sv.external
      GRPC_DNS_RESOLVER: native
    network_mode: host
    depends_on:
      - fluent-bit
    volumes:
      - data-favo:/var/lib/favo
    dns:
      - 127.0.0.1
    logging:
      driver: syslog
      options:
        syslog-address: udp://172.17.0.1:24224
        tag: "favo"
        syslog-format: "rfc5424"
    ports:
      - 7777:7777/tcp
      - 7778:7778/tcp
      - 7070:7070/tcp
    #labels:
    #  io.rancher.container.pull_image: always

# --------
# AVO
# --------

  avo:
    image: docker-registry.nextworks.it/avo:v0.32.20
    #hostname: avo
    environment:
      AVO_SERVICE_HOST: avo
      NAMING_HOST: nxw-sv:6900
      OSR_PORT: '2379'
      OSR_SERVER: nxw-etcd
      PPROF_ENABLED: 'false'
      REDIS_HOST: nxw-sv:6379
      LOGGER_LEVEL: INFO
      ETCD_EXTERNAL_SERVICE_HOST: etcd.external
      GRPC_DNS_RESOLVER: native
    network_mode: host
    depends_on:
      - fluent-bit
    volumes:
      - data-avo:/var/lib/avo
    dns:
      - 127.0.0.1
    logging:
      driver: syslog
      options:
        syslog-address: udp://172.17.0.1:24224
        tag: "avo"
        syslog-format: "rfc5424"
    ports:
      - 7080:7080/tcp
      - 7081:7081/tcp
      - 6701:6701/tcp
    #labels:
    #  io.rancher.container.pull_image: always

# --------
# AV CFG FE
# --------

  av-cfg-fe:
    image: docker-registry.nextworks.it/av-cfg-fe:v1.6.13
    environment:
      ETCD_SERVICE_HOST: nxw-etcd
      ETCD_SERVICE_PORT: '2379'
      PPROF_ENABLED: 'false'
      LOGGER_LEVEL: INFO
      GRPC_DNS_RESOLVER: native
    #stdin_open: true
    network_mode: host
    depends_on:
      - fluent-bit
    volumes:
      - nxw-sv-hermes:/mnt/nxw-sv/run:ro
    dns:
      - 127.0.0.1
    #tty: true
    logging:
      driver: syslog
      options:
        syslog-address: udp://172.17.0.1:24224
        tag: "av-cfg-fe"
        syslog-format: "rfc5424"
    ports:
      - 3401:3401/tcp
      - 10020:10020/tcp
      - 10021:10021/tcp
    #labels:
    #  io.rancher.container.pull_image: always

# --------
# GO2RTC
# --------

  go2rtc:
    image: docker-registry.nextworks.it/go2rtc:v1.4.11
    environment:
      PION_LOG_TRACE: all
      OSRD_SERVICE_GRPC_HOST: nxw-sv.external
      GRPC_DNS_RESOLVER: native
    stdin_open: true
    network_mode: host
    volumes:
      - nxw-sv-hermes:/mnt/nxw-sv/run:ro
      - nxw-sv-hermes:/hermes
    dns:
      - 127.0.0.1
    logging:
      driver: syslog
      options:
        syslog-address: udp://172.17.0.1:24224
        syslog-format: rfc5424
        tag: go2rtc
    ports:
      - 1985:1985/tcp
      - 1985:1985/udp
      - 1984:1984/tcp

# --------
# NXW ETCD
# --------

  nxw-etcd:
    image: docker-registry.nextworks.it/etcd-nxw:etcd_3_3_27-v0.0.6
    network_mode: managed
    depends_on:
      - nxw-sv
    environment:
      ETCD_CONF_FILE: /hermes/etcd.d/conf/etcd.conf.yml
      ETCD_DATA_DIR: /var/lib/etcd
      ETCD_RESET_STAMP_FILE: etcd_reset.stamp
      SUPERVISOR_SIG_SOCK: /hermes/etcd.d/run/etcd_signal.sock
      READY_TIMEOUT: '0'
      DEATH_INTERVAL_SEC: '120'
      DEATH_COUNT: '3'
      DISABLE_RESET_ON_CRASH: '0'
      GRPC_DNS_RESOLVER: native
    #stdin_open: true
    volumes:
      - nxw-sv-etcd-conf:/hermes/etcd.d/conf
      - nxw-sv-etcd-run:/hermes/etcd.d/run
      - nxw-sv-etcd-state:/var/lib/etcd
      - nxw-sv-persistance:/persistance:ro
    #tty: true
    ports:
      - 2379:2379/tcp
      - 2380:2380/tcp
    logging:
      driver: syslog
      options:
        syslog-address: udp://172.17.0.1:24224
        syslog-format: rfc5424
        tag: nxw-etcd

# --------
# CCTV BACKEND
# --------

  cctv-backend:
    image: docker-registry.nextworks.it/cctv-backend:v0.1.1
    environment:
      ETCD_SERVICE_HOST: nxw-sv
      ETCD_SERVICE_PORT: '2379'
      ETCD_SERVICE_TTL: '60'
      EXTERNAL_IFACE: eth0
      REDIS_SERVICE_HOST: nxw-sv
      REDIS_SERVICE_PORT: '6379'
      REDIS_WEBSERVER_KEY: global.web_server
      GO2RTC_SERVICE_HOST: nxw-sv
      GO2RTC_SERVICE_PORT: '1984'
      OSRD_SERVICE_HOST: osrd.external
      OSRD_SERVICE_GRPC_PORT: 8345
      GRPC_DNS_RESOLVER: native
    stdin_open: true
    network_mode: host
    dns:
      - 127.0.0.1
    tty: true
    logging:
      driver: syslog
      options:
        syslog-address: udp://172.17.0.1:24224
        tag: cctvbackend
        syslog-format: rfc5424

# ----------
# OSRD
# ----------

  osrd:
    image: docker-registry.nextworks.it/osrd:v1.4.1
    restart: on-failure
    network_mode: host
    dns: 127.0.0.1
    #ports:
    #  - '8345:8345'
    #  - '8346:8346'
    environment:
      - ETCD_SERVICE_HOST=nxw-etcd
      - ETCD_SERVICE_PORT=2379
      - OSRD_SERVICE_HOST=osrd.external
      - LOGS_LEVEL=debug
      - GRPC_DNS_RESOLVER=native
    depends_on:
      - fluent-bit
    volumes:
      - osrd-state:/var/lib/osrd/state
    # DNS points to dnrd on nxw-sv.
    # Using the ipsec ip address "attached" to docker0 interface
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "osrd"
        syslog-format: "rfc5424"


# ----------
# LOGROTATE
# ----------

  logrotate:
    image: "docker-registry.nextworks.it/logrotate:v0.1.2"
    network_mode: managed
    volumes:
      - container-logs:/var/log:rw
#    depends_on:
#      - fluent-bit
    logging:
      driver: "syslog"
      options:
        syslog-address: "udp://localhost:24224"
        tag: "logrotate"
        syslog-format: "rfc5424"

# ----------
# FLUENT-BIT
# ----------

  fluent-bit-data:
    image: docker-registry.nextworks.it/fluent-bit-data:v2.3.45-1
    network_mode: "none"
    labels:
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
      io.rancher.container.start_once: true
    volumes:
      - fluent-bit-data:/data:rw

  fluent-bit:
    depends_on:
      - logrotate
    image: "docker-registry.nextworks.it/fluent-bit:v0.3.1"
    network_mode: host
    ports:
      - "24224:24224" # "54:24224"
    volumes:
      - container-logs:/var/log:rw
      - fluent-bit-data:/data:ro
      - /var/run:/docker/var/run:ro
      - /var/log:/rancher/log:ro
    logging:
      driver: syslog
      options:
        syslog-address: udp://172.17.0.1:24224
        tag: "fluentbit"
        syslog-format: "rfc5424"


# ----------
# UHAL
# ----------

  uhal:
    image: docker-registry.nextworks.it/uhal:v0.51.2
    environment:
      - ETCD_SERVICE_HOST=nxw-etcd
      - ETCD_SERVICE_PORT=2379
      - EXTERNAL_IFACE=eth0
      - LICENSE_MANAGER_SERVICE_HOST=license-manager
      - LICENSE_MANAGER_SERVICE_QPORT=5001
      - LICENSE_MANAGER_SERVICE_SPORT=5000
      - RABBITMQ_SERVICE_HOST=rabbit.external
      - RABBITMQ_SERVICE_PORT=5672
      - RABBITMQ_SERVICE_MQTT_PORT=1883
      - RABBITMQ_SERVICE_AMQP_FALLBACK_HOST=rabbit.external
      - RABBITMQ_SERVICE_AMQP_FALLBACK_PORT=5672
      - UHAL_SERVICE_HOST=uhal
      - UHAL_SERVICE_PORT=5100
      - EVENT_SCHEMA_PATH=/usr/share/uHAL/json_events
      - GRPC_DNS_RESOLVER=native
    network_mode: host
    depends_on:
      - fluent-bit
    volumes:
      - data-uhal:/var/hermes/as-uhal
      - nxw-sv-hermes:/hermes
    restart: on-failure
    dns: 127.0.0.1
    logging:
      driver: syslog
      options:
        syslog-address: udp://172.17.0.1:24224
        tag: uhal
        syslog-format: "rfc5424"
    ports:
      - 5100:5100/tcp

# ----------
# LICENSE-MANAGER
# ----------

  license-manager:
    image: "docker-registry.nextworks.it/license-manager-be:v0.5.11"
    restart: on-failure
    network_mode: managed
    environment:
      - ETCD_SERVICE_HOST=nxw-etcd
      - ETCD_SERVICE_PORT=2379
      - LM_SOFT_DONGLE_PATH=/var/lib/license-manager/soft-dongle
      - LM_LICENSES_PATH=/var/lib/license-manager/licenses
      - REQUEST_BUFFER_SIZE=256
      - GRPC_DNS_RESOLVER=native
    privileged: yes
    depends_on:
      - fluent-bit
    devices:
      - /dev/:/dev:rw
    ports:
      - '5000:5000'
      - '5001:5001'
      - '5002:5002'
    volumes:
      - data-license-manager:/var/lib/license-manager:rw
      - /dev/bus/usb:/dev/bus/usb:rw
    # DNS points to dnrd on nxw-sv.
    # Using the ipsec ip address "attached" to docker0 interface
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "license-manager"
        syslog-format: "rfc5424"

# ----------
# SPA-CONFIG
# ----------

  spa-config:
    image: "docker-registry.nextworks.it/spa-config:v2.3.6"
    restart: on-failure
    # FIXME: The following network crap is a necessary evil to let the container
    # resolve osrd.external
    network_mode: host # crap: was managed
    dns: 127.0.0.1 # crap: it has been added
    environment:
      - ETCD_SERVICE_HOST=nxw-etcd
      - ETCD_SERVICE_PORT=2379
      - LOGS_LEVEL=INFO
      - OSRD_SERVICE_HOST=osrd.external
      - OSRD_SERVICE_GRPC_PORT=8345
      - GRPC_DNS_RESOLVER=native
    ports:
      - '8031:8031'
      - '8032:8032'
      - '5003:5003'
      - '5004:5004'
    depends_on:
      - fluent-bit
    volumes:
      #- spa-config-cfg:/usr/share/hermes/spa-config:rw
      - spa-config-db:/var/hermes/spa_servant:rw
      - sem-topology:/var/hermes/sem_servant:rw
      - ais-topology:/var/hermes/ais_servant:rw
      - tms-topology:/var/hermes/tms_servant:rw
    # DNS points to dnrd on nxw-sv.
    # Using the ipsec ip address "attached" to docker0 interface
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "spa-config"
        syslog-format: "rfc5424"

# ----------
# SEM
# ----------

  sem:
    image: "docker-registry.nextworks.it/spa-server:v2.2.12"
    restart: on-failure
    # FIXME: The following network crap is a necessary evil to let the container
    # resolve osrd.external
    network_mode: host # crap: was managed
    dns: 127.0.0.1 # crap: it has been added
    environment:
      - ETCD_SERVICE_HOST=nxw-etcd
      - ETCD_SERVICE_PORT=2379
      - PERSONALITY=sem1
      - IOR_PREFIX=SPA_SEM
      - CONFIG_PATH=/usr/share/hermes/sem_servant
      - TOPOLOGY_PATH=/var/hermes/sem_servant
      - IOR_PATH=/hermes/ior
      - SERVICE_HOST=sem
      - OSRD_SERVICE_HOST=osrd.external
      - OSRD_SERVICE_GRPC_PORT=8345
      - EXTERNAL_IFACE=eth0
      - GRPC_DNS_RESOLVER=native
    depends_on:
      - fluent-bit
      - spa-config
    ports:
      - '12344:12344'
      - '12345:12345'
      - '12346:12346'
    volumes:
      - sem-topology:/var/hermes/sem_servant:ro
      - nxw-sv-hermes:/hermes
    # DNS points to dnrd on nxw-sv.
    # Using the ipsec ip address "attached" to docker0 interface
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "sem"
        syslog-format: "rfc5424"

# ----------
# TMS
# ----------

  tms:
    image: "docker-registry.nextworks.it/spa-server:v2.2.12"
    restart: on-failure
    # FIXME: The following network crap is a necessary evil to let the container
    # resolve osrd.external
    network_mode: host # crap: was managed
    dns: 127.0.0.1 # crap: it has been added
    environment:
      - ETCD_SERVICE_HOST=nxw-etcd
      - ETCD_SERVICE_PORT=2379
      - PERSONALITY=tms1
      - IOR_PREFIX=SPA_TMS
      - CONFIG_PATH=/usr/share/hermes/tms_servant
      - TOPOLOGY_PATH=/var/hermes/tms_servant
      - IOR_PATH=/hermes/ior
      - SERVICE_HOST=tms
      - OSRD_SERVICE_HOST=osrd.external
      - OSRD_SERVICE_GRPC_PORT=8345
      - EXTERNAL_IFACE=eth0
      - GRPC_DNS_RESOLVER=native
    depends_on:
      - fluent-bit
      - spa-config
    ports:
      - '12364:12364'
      - '12365:12365'
      - '12366:12366'
    volumes:
      - tms-topology:/var/hermes/tms_servant:ro
      - nxw-sv-hermes:/hermes
    # DNS points to dnrd on nxw-sv.
    # Using the ipsec ip address "attached" to docker0 interface
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "tms"
        syslog-format: "rfc5424"

# ----------
# AIS
# ----------

  ais:
    image: "docker-registry.nextworks.it/spa-server:v2.2.12"
    restart: on-failure
    # FIXME: The following network crap is a necessary evil to let the container
    # resolve osrd.external
    network_mode: host # crap: was managed
    dns: 127.0.0.1 # crap: it has been added
    environment:
      - ETCD_SERVICE_HOST=nxw-etcd
      - ETCD_SERVICE_PORT=2379
      - PERSONALITY=ais1
      - IOR_PREFIX=SPA_AIS
      - CONFIG_PATH=/usr/share/hermes/ais_servant
      - TOPOLOGY_PATH=/var/hermes/ais_servant
      - IOR_PATH=/hermes/ior
      - SERVICE_HOST=ais
      - OSRD_SERVICE_HOST=osrd.external
      - OSRD_SERVICE_GRPC_PORT=8345
      - EXTERNAL_IFACE=eth0
      - GRPC_DNS_RESOLVER=native
    depends_on:
      - fluent-bit
      - spa-config
    ports:
      - '12354:12354'
      - '12355:12355'
      - '12356:12356'
    volumes:
      - ais-topology:/var/hermes/ais_servant:ro
      - nxw-sv-hermes:/hermes
    # DNS points to dnrd on nxw-sv.
    # Using the ipsec ip address "attached" to docker0 interface
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "ais"
        syslog-format: "rfc5424"

# ----------
# POSD
# ----------

  posd:
    image: "docker-registry.nextworks.it/posd:v0.6.23"
    restart: on-failure
    network_mode: host
    environment:
      - ETCD_SERVICE_HOST=nxw-etcd
      - ETCD_SERVICE_PORT=2379
      - NAVDATA_SERVICE_HOST=nxw-sv.external
      - NAVDATA_SERVICE_GRPC_PORT=7000
      - NAVDATA_SERVICE_REST_PORT=7001
      - RABBITMQ_SERVICE_HOST=rabbit.external
      - RABBITMQ_SERVICE_PORT=5672
      - GRPC_DNS_RESOLVER=native
    depends_on:
      - nxw-etcd
      - osrd
      - rabbitmq
      - plinsky
    ports:
      - '6966:6966'
      - '7000:7000'
      - '7001:7001'
    volumes:
      - posd-config:/var/lib/posd:rw
    dns: 127.0.0.1
    # DNS points to dnrd on nxw-sv.
    # Using the ipsec ip address "attached" to docker0 interface
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:24224
        tag: "posd"
        syslog-format: "rfc5424"

# ----------
#  WOL
# ----------
  wake-on-lan:
    image: docker-registry.nextworks.it/wake-on-lan:v0.0.1
    restart: on-failure
    network_mode: host
    hostname: "wake-on-lan"
    dns: 127.0.0.1
    environment:
      - ETCD_SERVICE_HOST=nxw-etcd
      - ETCD_SERVICE_PORT=2379
      - ETCD_SERVICE_TTL=60
      - LOGS_LEVEL=debug
      - EXTERNAL_IFACE=eth0
      - GRPC_DNS_RESOLVER=native
    depends_on:
      - fluent-bit
    logging:
      driver: syslog
      options:
        syslog-address: udp://172.17.0.1:24224
        tag: "wol"
        syslog-format: "rfc5424"


# ----------
# VOLUMES
# ----------

volumes:
  #spa-config-cfg:
  spa-config-db:
  #sem-topology:
  #ais-topology:
  #tms-topology:
  data-license-manager:
  data-plinsky-fuseki:
  bundle-manager-share:
  bundle-manager-state:
  data-alarm-manager:
  mongo-datavolume:
  data-channel-manager:
  mongodbconf:
  data-tex:
  data-chrono-manager:
  nxw-sv-root-persistent:
  data-analytic:
  data-favo:
  data-avo:
  osrd-state:
  logs:
  data-console-persistence:
  fluent-bit-data:
  container-logs:
  posd-config:
  nxw-sv-etcd-state:
  rabbitmq-data-volume:
  rabbitmq-init:
#  data-anomaly-manager:

