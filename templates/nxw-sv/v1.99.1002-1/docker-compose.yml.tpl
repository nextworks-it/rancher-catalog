version: '2'
services:

# ----------

  nxw-sv:
    privileged: true
    security_opt:
    - seccomp:unconfined
    image: docker-registry.nextworks.it/nxw-sv:1.99.1002-1
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

      # update-manager runs in a separate stack.
      # The HOST has to keep aligned with the actual
      # names in the form <service_name>.<stack_name>, or
      # it will not be resolved by using the <service_name> form.
      UPMGR_SERVICE_HOST: update-manager.update-manager.rancher.internal
      UPMGR_SERVICE_PORT: '54567'

      GUMON_AM_DISABLED: True
      GUMON_CHMGR_DISABLED: True
      #GUMON_LM_DISABLED: True
      #GUMON_FUSEKI_DISABLED: True
      #GUMON_PLINSKY_DISABLED: True

      ALARM_MANAGER_SERVICE_HOST: 'alarm-manager'
      ALARM_MANAGER_SERVICE_PORT1: '6977'
      ALARM_MANAGER_SERVICE_PORT2: '6978'

      CHANNEL_MANAGER_SERVICE_HOST: 'channel-manager'
      CHANNEL_MANAGER_SERVICE_PORT1: '6980'
      CHANNEL_MANAGER_SERVICE_PORT2: '9080'

      #LICENSE_MANAGER_SERVICE_HOST: 'license-manager'
      #LICENSE_MANAGER_SERVICE_SPORT: '5000'
      #LICENSE_MANAGER_SERVICE_QPORT: '5001'
      #PLINSKY_SERVICE_HOST: 'plinsky'
      #PLINSKY_SERVICE_PORT: '50051'

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
# ALARM MANAGER
# ----------

#  rabbit-container:
#    image: "rabbitmq:3.8"
#    container_name: "rabbitmq_server"
#    hostname: "rabbitmq_server"
#    ports:
#    - '5672:5672'
#    environment:
#    - RABBITMQ_DEFAULT_USER=rabbitmq
#    - RABBITMQ_DEFAULT_PASS=rabbitmq
#    - RABBITMQ_DEFAULT_VHOST=/
#    volumes:
#    - rabbitmq-data-volume:/var/lib/rabbitmq:rw
#    - ./init-rabbitmq.json:/etc/rabbitmq/definitions.json:ro
#
#  etcd-container:
#    image: "bitnami/etcd"
#
#    container_name: "etcd_server"
#    hostname: "etcd_server"
#    volumes:
#    - etcd-data-volume:/data/etcd
#    ports:
#    - "2379"
#    - "2380"
#    environment:
#    - ALLOW_NONE_AUTHENTICATION=yes

  mongodb-container:
    image: "mongo"
    container_name: "mongodb"
    restart: on-failure
    environment:
    - MONGO_INITDB_DATABASE="alarm_manager"
    volumes:
    #- ./init-mongo.js:/docker-entrypoint-initdb.d/init-mongo.js:ro
    - mongo-data-volume:/data/db:rw
    ports:
    - "27017"
    - "27018"
    - "27019"

  alarm-manager:
    image: docker-registry.nextworks.it/alarm-manager:v0.9.1-112-gb11c555a
    #container_name: "alarm_manager"
    restart: on-failure
    hostname: "alarm-manager"
    environment:
    - HOSTNAME_AM=alarm-manager
    links:
    - nxw-sv:etcd_server
    - mongodb-container:mongodb
    - nxw-sv:rabbitmq_server
    - channel-manager:channel_manager
    privileged: yes
    devices:
    - /dev/:/dev/
    ports:
    - '6977:6977'
    # protocol port remapped
    - '6978:6985'
    - '8085:8085'

    volumes:
    - data-alarm-manager:/var/run/alarm_manager:rw
    depends_on:
    - mongodb-container
    - nxw-sv

# ----------
# CHANNEL MANAGER
# ----------

  channel-manager:
    image: docker-registry.nextworks.it/channel-manager:0.9.1-23-g4d2385b
    #container_name: "channel-manager"
    hostname: "channel-manager"
    command:
    - channel-manager
    - --redis_host=redis_server
    links:
    - nxw-sv:redis_server
    - nxw-sv:etcd_server
    ports:
    - '6980:6980'
    - '9080:9080'

#    depends_on:
#      - redis
    volumes:
      - data-channel-manager:/var/run/channel-manager:rw

#  redis:
#          image: 'redis:alpine'
#          container_name: redis
#          hostname: "redis_server"
#          environment:
#            - ALLOW_EMPTY_PASSWORD=yes
#          ports:
#            - '6379:6379'

# ----------
# VOLUMES
# ----------

volumes:
  data-alarm-manager:
  mongo-data-volume:
#  etcd-data-volume:
#  rabbitmq-data-volume:
  data-channel-manager:

