sinatra-chef-node
=================


Tiny Sinatra app to Create/Delete Chef Node/Clients.

As Open Source Chef Server does not have RBAC User Access Control, setting up a restricted user access is not fully achievable. Using this App somewhat restricted user access can be implemented.

> This App is not a replacement or alternative in any way to knife client or chef api
calls to perform what it does.

**Where to Use it?**

I am using this App to make API calls to provision chef client without any manual step.

A simple curl command can generate client certificate and also update run_list for the node. e.g.

```sh
curl  -X POST -d 'fqdn=FQDN&role=role[system],role[base],recipe[bootstrap]&env=ENVIRONMENT' -u USER:PASSWORD "https://SERVER:PORT/node" --insecure
```

It makes chef client very easy, especially Amazon Instances provisioning as it can be easily added to User Data.

Chef client PEM certificate file is stored by default on the server which can be used as a backup or to retrieve client certificate later. 

**Prerequisites**

- chef server
- knife installed and configured
- sinatra installed
- server SSL certificate bundle

**Available API calls**

- create client PEM key File
- create node and also define run list
- delete client and Node
- retrieve client PEM key file in case of server loss, also very
  helpful during provisioning failures

**HTTP Request Methods**

All api calls are route to '/node'. Available HTTP request methods are:

- GET : provides a node PEM key file from server filesystem directory
- DELETE : deletes chef client \& node along with files stored on sever
- POST : creates chef client \& node with provided run_list, a success
  response returns Client PEM key file

**HTTP Data / Parameters**

- fqdn : chef client fqdn
- run_list : chef node run_list, more than one item ',' separated
- env : chef node environment

**Install Gems**

```sh
gem install sinatra json 
```

**Run App**

```sh
ruby sinatra-chef-node.rb
```

This App is designed to do limited tasks. It can have more functionality, but that
does not seems a correct approach to solve the problem.


License
----

Apache v2.0


**Open Source!**
