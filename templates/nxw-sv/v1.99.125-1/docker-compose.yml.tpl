version: '2'
services:
  nxw-sv:
    privileged: true
    security_opt:
    - seccomp:unconfined
    image: docker-registry.nextworks.it/nxw-sv:1.99.125-1
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
    entrypoint:
    - /sbin/init
    stop_grace_period: 1m30s
    stop_signal: SIGINT
    labels:
      io.rancher.container.dns: 'true'
      io.rancher.container.network: 'true'
      io.rancher.container.pull_image: always
    environment:
      # Temporary fixes
      PYTHONPATH: /opt/hermes/lib/python

      UPMGR_SERVICE_HOST: update-manager.update-manager.rancher.internal
      UPMGR_SERVICE_PORT: '54567'

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
