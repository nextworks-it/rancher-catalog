version: '2'
services:

# ----------
# SUPERVISOR
# ----------

  nxw-sv:
    privileged: true
    security_opt:
      - seccomp:unconfined
    image: docker-registry.nextworks.it/nxw-sv:2.0.4-1
    restart: on-failure
    stdin_open: true
    network_mode: host
    hostname: supervisor
    volumes:
      - /dev:/dev:rw
      - nxw-sv-hermes:/hermes
      - nxw-sv-data:/mnt/data
      - nxw-sv-logs:/var/log
      # the following are used as upperdir and workdir
      # to overlay mount the related image dirs
      - nxw-sv-persistance:/persistance
      - nxw-sv-www:/var/www
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
      #GUMON_FUSEKI_DISABLED: True
      #GUMON_PLINSKY_DISABLED: True

      ALARM_MANAGER_SERVICE_HOST: 'alarm-manager'
      ALARM_MANAGER_SERVICE_PORT: '8085'   # REST

      CHANNEL_MANAGER_SERVICE_HOST: 'channel-manager'
      CHANNEL_MANAGER_SERVICE_PORT1: '6980'
      CHANNEL_MANAGER_SERVICE_PORT2: '9080'

      #LICENSE_MANAGER_SERVICE_HOST: 'license-manager'
      #LICENSE_MANAGER_SERVICE_SPORT: '5000'
      #LICENSE_MANAGER_SERVICE_QPORT: '5001'
      #PLINSKY_SERVICE_HOST: 'plinsky'
      #PLINSKY_SERVICE_PORT: '50051'

      TEX_SERVICE_HOST: 'tex-server'
      TEX_SERVICE_PORT: '11051'

# ----------
# OLD IMAGES CLEANUP
# ----------

  janitor:
    privileged: true
    image: meltwater/docker-cleanup:1.8.0
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
# LICENSE MANAGER
# ----------

#  license-manager:
#    image: docker-registry.nextworks.it/license-manager-nodongle:v0.2.27
#    network_mode: managed
#    security_opt:
#    - seccomp:unconfined
#    privileged: yes
#    entrypoint:
#    - license-manager
#    - -i0.0.0.0
#    volumes:
#    - /dev:/dev:rw
#    - license-manager-data:/var/lib/license-manager
#    labels:
#      io.rancher.container.dns: 'true'
#      io.rancher.container.network: 'true'
#      io.rancher.container.pull_image: always

# ----------
# PLINSKY
# ----------

#  plinsky:
#    image: docker-registry.nextworks.it/plinsky:v0.1.15
#    network_mode: managed
#    depends_on:
#    - fuseki
#    volumes_from:
#    - fuseki
#    # The below "pippo" is the fuseki dataset neme,
#    # which is hardcoded in apache-jena-fuseki image,
#    # into fuseki .ttl config
#    entrypoint:
#    - /usr/local/bin/plinsky
#    - --fuseki_host=fuseki
#    - --fuseki_port=3030
#    - --fuseki_dataset=pippo
#    - --fuseki_base_dir=/var/lib/apache-jena-fuseki/run
#    - --osr_host=nxw-sv
#    - --osr_port=2379
#    - --workers=10
#    labels:
#      io.rancher.container.dns: 'true'
#      io.rancher.container.network: 'true'
#      io.rancher.container.pull_image: always
#      io.rancher.sidekicks: fuseki
#
#  fuseki:
#    image: docker-registry.nextworks.it/apache-jena-fuseki:v3.9.0-1
#    volumes:
#    - fuseki-data:/var/lib/apache-jena-fuseki
#    labels:
#      io.rancher.container.dns: 'true'
#      io.rancher.container.network: 'true'
#      io.rancher.container.pull_image: always

# ----------
# PANEL FACTORY BE
# ----------

  panels-factory-be:
    image: docker-registry.nextworks.it/panels-factory-be:v1.0.12
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
      - nxw-sv-www:/var/www:rw
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
      - mqttcerts:/data/mqtt/certs
    entrypoint: /bin/true

  alarm-manager:
    image: docker-registry.nextworks.it/alarm-manager:v0.10.8
    restart: on-failure
    network_mode: host
    # dns points to dnrd on nxw-sv, which runs in network nost mode
    dns: 127.0.0.1
    environment:
      - CONF_PATH=/etc/hermes/alarm_manager
      - DATA_PATH=/var/run/alarm_manager
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
    image: "mongo"
    container_name: "mongodb"
    restart: on-failure
    environment:
      - MONGO_INITDB_DATABASE="alarm_manager"
    volumes:
      - mongodbconf:/docker-entrypoint-initdb.d/:ro
      - mongo-datavolume:/data/db:rw
    ports:
      - "27017:27017"
      - "27018:27018"
      - "27019:27019"
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
    image: docker-registry.nextworks.it/template-expander:v0.1.1
    restart: on-failure
    entrypoint: [ "/usr/local/bin/nxwtex", "--templ_dir", "/TEMPLATES" ]
    #command: [ "--port", "11051" ]
    ports:
      - "11051:11051"
    environment:
      - PLINSKY_SERVICE_HOST=nxw-sv
      - PLINSKY_SERVICE_PORT=50051
      - TEX_SERVICE_PORT=11051
      - TZ_SERVICE_HOST=nxw-sv
      - TZ_SERVICE_PORT=9001
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

  mqtt:
    image: docker-registry.nextworks.it/http-mqtt:1.0.0
    restart: on-failure
    environment:
      - MQTT_HOST=a336hpuhg3xio4-ats.iot.eu-west-1.amazonaws.com
      - MQTT_PORT=8883
      - MQTT_CLIENT_ID=env42-mqtt2http
      - MQTT_SUB_TOPIC=dev/env/42/rpc/+
      - MQTT_CA_PATH=/certs/rootCA.pem
      - MQTT_CRT_PATH=/certs/cert.crt
      - MQTT_KEY_PATH=/certs/private.key
    volumes:
      - mqttcerts:/certs:ro
    depends_on:
      - alarm-manager-datavolume
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
        tag: "mqtt"

# ----------
# CONDITIONS-GATEWAY
# ----------

  conditions-gateway:
    image: docker-registry.nextworks.it/conditions-gateway:v0.0.18
    restart: on-failure
    ports:
      - '8001:8001'
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
    image: docker-registry.nextworks.it/channel-manager:v0.9.138
    # DNS points to dnrd on nxw-sv.
    # Using the ipsec ip address "attached" to docker0 interface
    network_mode: host
    dns: 127.0.0.1
    environment:
      - CHANNEL_MANAGER_SERVICE_HOST=channel-manager
      - ETCD_SERVICE_HOST=nxw-sv
      - ETCD_SERVICE_PORT=2379
      - REDIS_SERVICE_HOST=nxw-sv
      - REDIS_SERVICE_PORT=6379
      - TEX_SERVICE_HOST=tex-server
      - TEX_SERVICE_PORT=11051
    command:
      - channel-manager
    ports:
      - '9080:9080'
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


# ----------
# VOLUMES
# ----------

volumes:
  data-alarm-manager:
  mongo-datavolume:
  data-channel-manager:
  mongodbconf:
  mqttcerts:
  data-tex:

