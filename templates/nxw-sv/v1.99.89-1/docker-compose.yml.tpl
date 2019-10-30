version: '2'
services:
  nxw-sv:
    privileged: true
    security_opt:
    - seccomp:unconfined
    image: docker-registry.nextworks.it/nxw-sv:1.99.89-1
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
