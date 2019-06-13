version: '2'
services:
  nxw-sv:
    cap_add:
    - AUDIT_WRITE
    - CHOWN
    - DAC_OVERRIDE
    - FOWNER
    - FSETID
    - KILL
    - MAC_ADMIN
    - MAC_OVERRIDE
    - MKNOD
    - NET_ADMIN
    - NET_BIND_SERVICE
    - NET_BROADCAST
    - NET_RAW
    - SETFCAP
    - SETGID
    - SETPCAP
    - SETUID
    - SYSLOG
    - SYS_ADMIN
    - SYS_BOOT
    - SYS_CHROOT
    - SYS_NICE
    - SYS_PACCT
    - SYS_PTRACE
    - SYS_RAWIO
    - SYS_TIME
    - SYS_TTY_CONFIG
    security_opt:
    - seccomp:unconfined
    image: docker-registry.nextworks.it/nxw-sv:1.99.60-1
    devices:
    - /dev/bus/usb:/dev/bus/usb:rwm
    - /dev/ttyS0:/dev/ttyS0:rwm
    - /dev/ttyS1:/dev/ttyS1:rwm
    - /dev/ttyS2:/dev/ttyS2:rwm
    - /dev/ttyS3:/dev/ttyS3:rwm
{{- if eq .Values.SERIALUSB0 "true"}}
    - /dev/ttyUSB0:/dev/ttyUSB0
{{- end}}
{{- if eq .Values.SERIALUSB1 "true"}}
    - /dev/ttyUSB1:/dev/ttyUSB1
{{- end}}
{{- if eq .Values.SERIALUSB2 "true"}}
    - /dev/ttyUSB2:/dev/ttyUSB2
{{- end}}
{{- if eq .Values.SERIALUSB3 "true"}}
    - /dev/ttyUSB3:/dev/ttyUSB3
{{- end}}

    stdin_open: true
    network_mode: host
    hostname: supervisor
    volumes:
    - /mnt/nxw-sv/hermes:/hermes
    - nxw-sv-data:/mnt/data
    - nxw-sv-logs:/var/log
    tty: true
    command:
    - /sbin/init
    labels:
      # The below label requires l2-flat cni to be installed as stack.
      # TODO: complete this compose to bring the dependecy in.
      #io.rancher.cni.network: l2-flat
      io.rancher.container.network: 'true'
      io.rancher.container.pull_image: always
