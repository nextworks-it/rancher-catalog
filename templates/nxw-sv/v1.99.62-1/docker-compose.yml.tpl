version: '2'
services:
  nxw-sv:
    privileged: true
    security_opt:
    - seccomp:unconfined
    image: docker-registry.nextworks.it/nxw-sv:1.99.62-1
    stdin_open: true
    network_mode: host
    hostname: supervisor
    volumes:
    - /mnt/nxw-sv/hermes:/hermes
    - nxw-sv-data:/mnt/data
    - nxw-sv-logs:/var/log
    - /dev:/dev:rw
    tty: true
    command:
    - /sbin/init
    labels:
      # The below label requires l2-flat cni to be installed as stack.
      # TODO: complete this compose to bring the dependecy in.
      #io.rancher.cni.network: l2-flat
      io.rancher.container.network: 'true'
      io.rancher.container.pull_image: always
