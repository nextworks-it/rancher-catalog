version: '2'
services:

# ----------
# SUPERVISOR
# ----------

  nxw-sv:
    privileged: true
    security_opt:
      - seccomp:unconfined
    image: docker-registry.nextworks.it/nxw-sv:2.0.45-1
    restart: on-failure
    stdin_open: true
    network_mode: host
    hostname: supervisor
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
    tty: true
    # The entrypoint sets network defaults
    # and other initial setups to prepare the container environment
    entrypoint: /entrypoint.sh
    stop_grace_period: 1m30s
    stop_signal: SIGINT
    labels:
      io.rancher.container.dns: 'true'
      io.rancher.container.network: 'true'
      io.rancher.container.pull_image: always
    environment:
      # Temporary fixes
      PYTHONPATH: /opt/hermes/lib/python

      # oamd runs in a separate stack.
      # The HOST has to keep aligned with the actual
      # names in the form <service_name>.<stack_name>, or
      # it will not be resolved by using the <service_name> form.
      OAMD_SERVICE_HOST: oamd.oamd.rancher.internal
      OAMD_SERVICE_PORT: '54567'

      ETCD_SERVICE_HOST: 'nxw-sv'
      ETCD_SERVICE_PORT: '2379'

      GUMON_AM_DISABLED: True
      GUMON_CHMGR_DISABLED: True
      #GUMON_LM_DISABLED: True
      GUMON_PLINSKY_DISABLED: True

      ALARM_MANAGER_SERVICE_HOST: 'alarm-manager'
      ALARM_MANAGER_SERVICE_PORT: '8085'   # REST

      CHANNEL_MANAGER_SERVICE_HOST: 'channel-manager'
      CHANNEL_MANAGER_SERVICE_PORT1: '6980'
      CHANNEL_MANAGER_SERVICE_PORT2: '9080'

      #LICENSE_MANAGER_SERVICE_HOST: 'license-manager'
      #LICENSE_MANAGER_SERVICE_SPORT: '5000'
      #LICENSE_MANAGER_SERVICE_QPORT: '5001'

      PLINSKY_SERVICE_HOST: 'plinsky'
      PLINSKY_SERVICE_PORT: '50051'

      BUNDLE_MANAGER_SERVICE_HOST: 'bundle-manager'
      BUNDLE_MANAGER_SERVICE_PORT: '8345'

      BUNDLE_BASEPATH: '/usr/share/bundle-man'
      FVPROXY_BUNDLE_DIR: 'fvproxy'

      TEX_SERVICE_HOST: 'tex-server'
      TEX_SERVICE_PORT: '11051'

# ----------
# OLD IMAGES CLEANUP
# ----------

  janitor:
    privileged: true
    image: docker-registry.nextworks.it/docker-cleanup:1.8.0
    environment:
      CLEAN_PERIOD: '3600'
      DEBUG: '0'
      DELAY_TIME: '900'
      KEEP_CONTAINERS: '*:*'
      KEEP_CONTAINERS_NAMED: '*-datavolume, *nxw-sv*'
      KEEP_IMAGES: rancher/
      LOOP: 'true'
    network_mode: none
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
        syslog-address: udp://172.17.0.1:5000
        tag: "janitor"

# ----------
# PANEL FACTORY BE
# ----------

  panels-factory-be:
    image: docker-registry.nextworks.it/panels-factory-be:v1.0.23
    restart: on-failure
    network_mode: managed
    ports:
      - '7110:7110/tcp'
    environment:
      - ETCD_SERVICE_HOST=nxw-sv
      - ETCD_SERVICE_PORT=2379
      - REDIS_SERVICE_HOST=nxw-sv
      - REDIS_SERVICE_PORT=6379
      - NAMING_HOST=nxw-sv
      - NAMING_PORT=6900
    volumes:
      - nxw-sv-www-remotes:/var/www/localhost/htdocs/remotes:rw
      - nxw-sv-hermes:/mnt/nxw-sv/run:ro
    depends_on:
      - nxw-sv
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:5000
        tag: "panels-factory-be"
    #labels:
    #  io.rancher.container.pull_image: always

# ----------
# BUNDLE MANAGER
# ----------

  bundle-manager:
    image: docker-registry.nextworks.it/bundle-manager:v0.2.2
    restart: on-failure
    network_mode: managed
    #ports:
    #  - "8345:8345"
    environment:
      - ETCD_SERVICE_HOST=nxw-sv
      - ETCD_SERVICE_PORT=2379
    volumes:
      - bundle-manager-share:/usr/share/bundle-man/share
      - bundle-manager-state:/var/lib/bundle-man/state
    depends_on:
      - nxw-sv
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:5000
        tag: "bundle-manager"

# ----------
# PLINSKY
# ----------

  fuseki:
    image: "docker-registry.nextworks.it/fuseki:v3.12.0-3"
    network_mode: managed
    #ports:
    #  - "3030:3030"
    volumes:
      - data-plinsky-fuseki:/var/lib/apache-jena-fuseki
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:5000
        tag: "fuseki"

  plinsky:
    image: "docker-registry.nextworks.it/plinsky:v0.4.9"
    network_mode: host
    # dns points to dnrd on nxw-sv, which runs in network nost mode
    dns: 127.0.0.1
    ports:
      - "50051:50051"
    volumes:
      - data-plinsky-fuseki:/var/lib/apache-jena-fuseki
      - bundle-manager-share:/mnt:ro
    depends_on:
      - fuseki
    environment:
      - FUSEKI_SERVICE_HOST=fuseki
      - FUSEKI_SERVICE_PORT=3030
      - ETCD_SERVICE_HOST=nxw-sv
      - ETCD_SERVICE_PORT=2379
      - EXTERNAL_IFACE=eth0
      - BUNDLE_BASEPATH=/mnt
      - BUNDLE_DIR=plinsky
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
        syslog-address: udp://172.17.0.1:5000
        tag: "plinsky"

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
    image: docker-registry.nextworks.it/alarm-manager:v0.13.1
    restart: on-failure
    network_mode: host
    # dns points to dnrd on nxw-sv, which runs in network nost mode
    dns: 127.0.0.1
    environment:
      - CONF_PATH=/etc/hermes/alarm_manager
      - DATA_PATH=/var/run/alarm_manager
      - AM_DEBUG_ENABLED=false
      - ALARM_MANAGER_SERVICE_HOST=alarm-manager
      - ETCD_SERVICE_HOST=nxw-sv
      - ETCD_SERVICE_PORT=2379
      - MONGODB_SERVICE_HOST=mongodb
      - MONGODB_SERVICE_PORT=27017
      - RABBITMQ_SERVICE_HOST=rabbit.external
      - RABBITMQ_SERVICE_PORT=5672
      - ALARM_MANAGER_CLOUD_ENABLED=false
      - ALARM_MANAGER_ACTIVE_FILTERS=false
      - MAINTENANCE_SERVICE_REST_PORT=8086
      - MAX_CONN_POOL_DB=20
      - DB_USE_ALWAYS_DISK_ON_QUERY=true
      - DB_MAX_RESULTS_ALLOWED=100000
      - MAX_USER_QUEUE_LENGTH=1000
      - EXPORT_MAX_BULK_ALARMS=10000
      - BUNDLE_BASEPATH=/etc/hermes/alarm_manager/cloud
      - BUNDLE_DIR=alarm-manager
      - CLOUD_CONF_AMFILE=aws.json
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
        syslog-address: udp://172.17.0.1:5000
        tag: "alarm-manager"

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
      - alarm-manager-datavolume
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:5000
        tag: "mongodb"

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
    # tex-server requires the console (nxw-sv) just to get the timezone and
    # plinsky for info resolution
    depends_on:
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
        syslog-address: udp://172.17.0.1:5000
        tag: "template-expander"

# ----------
# HTTP-MQTT
# ----------
# NOTE: Keep the following service name as 'mqtt' until SP-880 is fixed

  mqtt:
    image: docker-registry.nextworks.it/http-mqtt:v1.0.18
    restart: on-failure
    environment:
       - ETCD_SERVICE_HOST=nxw-sv
       - ETCD_SERVICE_PORT=2379
       - SERVICES=alarm-manager:http://alarm-manager:8086
    #  - MQTT_HOST=a336hpuhg3xio4-ats.iot.eu-west-1.amazonaws.com
    #  - MQTT_PORT=8883
    #  - MQTT_CLIENT_ID=env42-mqtt2http
    #  - MQTT_SUB_TOPIC=dev/env/42/rpc/+
    #  - MQTT_CA_PATH=/certs/rootCA.pem
    #  - MQTT_CRT_PATH=/certs/cert.crt
    #  - MQTT_KEY_PATH=/certs/private.key
    volumes:
      - bundle-manager-share:/var/lib/bundle-man:ro
    network_mode: managed
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
        syslog-address: udp://172.17.0.1:5000
        tag: "http-mqtt"

# ----------
# CONDITIONS-GATEWAY
# ----------

  conditions-gateway:
    image: docker-registry.nextworks.it/conditions-gateway:v0.0.28
    restart: on-failure
    network_mode: managed
    #ports:
    #  - '8001:8001'
    environment:
      - ETCD_SERVICE_HOST=nxw-sv
      - ETCD_SERVICE_PORT=2379
      - CGW_SERVICE_HOST=conditions-gateway
      - CGW_SERVICE_PORT=8001
    depends_on:
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
        syslog-address: udp://172.17.0.1:5000
        tag: "conditions-gateway"

# ----------
# CHANNEL MANAGER
# ----------

  channel-manager:
    image: docker-registry.nextworks.it/channel-manager:v0.9.141
    # DNS points to dnrd on nxw-sv.
    # Using the ipsec ip address "attached" to docker0 interface
    network_mode: managed
    #ports:
    #  - '9080:9080'
    dns: 127.0.0.1
    environment:
      - CHANNEL_MANAGER_SERVICE_HOST=channel-manager
      - ETCD_SERVICE_HOST=nxw-sv
      - ETCD_SERVICE_PORT=2379
      - REDIS_SERVICE_HOST=nxw-sv
      - REDIS_SERVICE_PORT=6379
      - TEX_SERVICE_HOST=tex-server
      - TEX_SERVICE_PORT=11051
      - AM_CONNECTION_TIMEOUT=20
      - AM_CONNECTION_RETRY=3
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
        syslog-address: udp://172.17.0.1:5000
        tag: "channel-manager"

# --------------
# CHRONO MANAGER
# --------------

  chrono-manager:
    image: docker-registry.nextworks.it/chrono-manager:v0.99.23
    restart: on-failure
    #network_mode: managed (depends on SP-649)
    ports:
      - "12040:12040"
    network_mode: host
    dns: 127.0.0.1
    depends_on:
      - nxw-sv
      - plinsky
    environment:
      - ETCD_SERVICE_HOST=nxw-sv
      - ETCD_SERVICE_PORT=2379
      - RABBITMQ_SERVICE_HOST=rabbit.external
      - RABBITMQ_SERVICE_PORT=5672
      - EXTERNAL_IFACE=eth0
      - TZ_SERVICE_HOST=nxw-sv
      - TZ_SERVICE_PORT=9001
      - REDIS_SERVICE_HOST=nxw-sv
      - REDIS_SERVICE_PORT=6379
      - REDIS_WEBSERVER_KEY=global.web_server
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
        syslog-address: udp://172.17.0.1:5000
        tag: "chrono-manager"

# ----------
# VOLUMES
# ----------

volumes:
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
