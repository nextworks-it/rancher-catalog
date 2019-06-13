version: '2'
services:
  update-manager:
    image: docker-registry.nextworks.it/update-manager:v0.0.22
    # keep API_PORT fixed to the upmgr default
    ports:
      - ${HOST_PORT}:54567
    entrypoint: /bin/upmgr
    command: [
      "--api-addr", "${API_ADDR}",
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
    network_mode: host
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
