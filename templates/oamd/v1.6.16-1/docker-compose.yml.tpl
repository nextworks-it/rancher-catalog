version: '2'
services:
  oamd:
    image: docker-registry.nextworks.it/oamd:v1.6.16
    restart: on-failure
    # keep API_PORT fixed to the oamd default
    ports:
      - ${HOST_PORT}:54567
    entrypoint: /bin/oamd
    environment:
      GRPC_ADDR: ${API_ADDR}
      GRPC_PORT: ${HOST_PORT}
      REST_ADDR: ${REST_ADDR}
      REST_PORT: ${REST_PORT}
      RANCHER_ADDR: ${RANCHER_ADDR}
      RANCHER_PORT: ${RANCHER_PORT}
      RANCHER_AKEY: ${RANCHER_AKEY}
      RANCHER_SKEY: ${RANCHER_SKEY}
      RANCHER_PROJECT: ${RANCHER_PROJECT}
      RANCHER_STACK: ${RANCHER_STACK}
      RANCHER_POLL_DELAY: ${RANCHER_POLL_DELAY}
      RANCHER_REQ_TOUT: ${RANCHER_REQ_TOUT}
      RANCHER_CATALOG_REMAP: ${RANCHER_CATALOG_REMAP}
      LOGS_LEVEL: ${LOGS_LEVEL}
      DOCKER_HOST: "unix:///var/run/docker.sock"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - oamd-state:/var/lib/oamd/state
    network_mode: bridge
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable tu such address.
        syslog-address: udp://172.17.0.1:24224
        syslog-format: "rfc5424"
        tag: "oamd"
    labels:
      io.rancher.container.network: 'true'
      io.rancher.container.pull_image: always
#    health_check:
#      port: ${HOST_PORT}
      # For TCP, request_line needs to be '' or not shown
      # TCP Example:
      # request_line: ''
      #request_line: GET / HTTP/1.0
#      interval: 60000
#      unhealthy_threshold: 3
#      healthy_threshold: 2
#      response_timeout: 2000
#      strategy: recreate

volumes:
  oamd-state:


