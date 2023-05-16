version: '2'
volumes:
  nodered-data: {}
services:
  nxw-nodered:
    image: docker-registry.nextworks.it/nodered-nxw-nodes:v0.1.5-2
    environment:
      ETCD_SERVICE_HOST: nxw-sv.nxw-sv
      ETCD_SERVICE_PORT: '2379'
      RABBITMQ_SERVICE_HOST: nxw-sv.nxw-sv
      RABBITMQ_SERVICE_PORT: '5672'
      RESTIFIER_SERVICE_HOST: nxw-sv.nxw-sv
      RESTIFIER_SERVICE_PORT: '4995'
    volumes:
    - nodered-data:/data
    ports:
    - 1880:1880/tcp
    labels:
      io.rancher.container.pull_image: always
      it.nextworks.dependencies: "nxw-sv >= 2.3.2"
    logging:
      driver: syslog
      options:
        # Using the docker bridge address of host node
        # to reach the supervisor.
        # This is a trick which works since the supervisor container runs in
        # 'host' networking mode, so the syslog running on supervisor is also
        # reachable to such address.
        syslog-address: udp://172.17.0.1:5000
        tag: "nxw-nodered"



