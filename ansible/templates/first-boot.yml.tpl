---
- hosts: localhost
  connection: local
  remote_user: root
  become: yes
  vars:
    ami_hostname: "{{ ansible_hostname }}"
    ami_ip_address: "{{ ansible_eth0.ipv4.address }}"
    var_lib_device: "{{var_lib_device}}"
    use_local_device: "{{use_local_device}}"
    fs_volume_type: "{{fs_volume_type}}"
    fs_volume_options:
{{fs_volume_options | to_nice_yaml | indent(8,first=true) }}

{% raw %}
    ami_role: "{{ role }}"
    ami_project: "{{ project }}"
    ami_env: "{{ env }}"
  tasks:
   - pip: name={{item}} state=latest
     with_items:
     - awscli
     - boto

   # AWS
   - name: AWS
     block:
     - name: Get the instance id
       uri:
         url: http://169.254.169.254/latest/meta-data/instance-id
         return_content: yes
       register: metadatainstanceid
     - name: "Set facts instance id"
       set_fact: instance_id="{{ metadatainstanceid.content }}"
     when: ansible_system_vendor == "Amazon EC2"

   # GCP
   - name: GCP
     block:
     - name: Get instance ID from google metadatas
       uri:
         url: http://metadata/computeMetadata/v1/instance/id
         return_content: yes
         headers:
           Metadata-Flavor: "Google"
       register: gcp_instance_id
     - name: "Set facts instance id"
       set_fact: instance_id="{{ gcp_instance_id.content }}"
     when: ansible_system_vendor == "Google"


   # override var_lib_device by local if needed
   - name: found local disk
     find:
       paths: /dev
       file_type: any
       patterns: "local0,xvdg"
     register: dev_files
     when: use_local_device|bool == true

   - name: get device name
     set_fact:
       var_lib_device: "{{ dev_files.files[0].path }}"
     no_log: True
     when: use_local_device|bool == true and dev_files.files

   - name: "Set facts with hostname"
     set_fact: ansible_hostname="{{ ami_project|lower }}-{{ ami_role|lower }}-{{ ami_env|lower }}-{{ instance_id | default(ansible_default_ipv4.address | replace('.', '-'), true) }}"

   # Due to ansible set hostname issue https://github.com/ansible/ansible/issues/25543
   - name: install dbus
     package:
       name: dbus
       state: present
   - name: Ensure dbus started
     service:
       name: dbus
       state: started


   - name: "Setup instance hostname"
     hostname: name="{{ ansible_hostname | truncate(64, False, '') }}"

   - name: "Setup instance AWS Hosts file"
     lineinfile: dest=/etc/hosts
                 regexp='^{{ ansible_eth0.ipv4.address }}.*'
                 line="{{ ansible_eth0.ipv4.address }} {{ ansible_hostname | truncate(64, False, '') }}"
                 state=present

   - name: "Find files containing packer's hostname"
     shell: grep -iR "{{ ami_hostname }}" /etc/ | grep -v 'Binary' | cut -f 1 -d ':' |  sort -u
     register: relics_hostname

   - name: "Replace all occurences of packer's hostname"
     replace:
       dest: "{{ item }}"
       regexp: "{{ ami_hostname }}"
       replace: "{{ ansible_hostname | truncate(64, False, '') }}"
     with_items: "{{ relics_hostname.stdout_lines }}"

   - name: "Find files containing packer's IP address"
     shell: grep -iR "{{ ami_ip_address }}" /etc/ | grep -v 'Binary' | cut -f 1 -d ':' |  sort -u
     register: relics_ip_address

   - name: "Replace all occurences of packer's IP address"
     replace:
       dest: "{{ item }}"
       regexp: "{{ ami_ip_address }}"
       replace: "{{ ansible_eth0.ipv4.address }}"
     with_items: "{{ relics_ip_address.stdout_lines }}"

   - name: "volume - Check if persistent device need to be initialized"
     command: "file -s {{var_lib_device}} --dereference"
     ignore_errors: True
     register: initiate_volume_device
     failed_when: "\"{{ fs_volume_options[fs_volume_type]['initiate_volume_stdout'] }}\" in initiate_volume_device.stdout"

   - name: "volume - Format persistent volume in ext4"
     command: "{{ fs_volume_options[fs_volume_type]['mkfs_command'] }} -L ephemeral0 {{var_lib_device}}"
     when: initiate_volume_device|success

{% endraw %}
