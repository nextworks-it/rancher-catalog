version: '2'
services:
  oamd:
    image: docker-registry.nextworks.it/oamd:v0.3.3
    restart: on-failure
    # keep API_PORT fixed to the oamd default
    ports:
      - ${HOST_PORT}:54567
    entrypoint: /bin/oamd
    command: [
      "--grpc-addr", "${API_ADDR}",
      "--rest-addr", "${REST_ADDR}",
      "--rest-port", "${REST_PORT}",
      "--rancher-port", "${RANCHER_PORT}",
      "--rancher-addr", "${RANCHER_ADDR}",
      "--rancher-akey", "${RANCHER_AKEY}",
      "--rancher-skey", "${RANCHER_SKEY}",
      "--rancher-stack", "${RANCHER_STACK}",
      "--rancher-project", "${RANCHER_PROJECT}",
      "--rancher-poll-delay", "${RANCHER_POLL_DELAY}",
      "--rancher-req-tout", "${RANCHER_REQ_TOUT}",
      "--log-level", "${LOG_LEVEL}"
    ]
    network_mode: bridge
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable tu such address.
        syslog-address: udp://172.17.0.1:5000
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
