require 'sinatra'
require 'json'
require 'webrick'
require 'webrick/https'
require 'openssl'

# Directory to store Chef Nodes/Clients
NODES_LOCATION = './nodes'

# SSL Certificates Directory
SSL_CERT_LOCATION = './ssl'

# Default HTTP Error Response Code
HTTP_ERROR_RESPONSE = 418

class SinatraChefNode < Sinatra::Base
  # Enable Basic Auth
  use Rack::Auth::Basic, "Restricted Area" do |username, password|
    username == 'MUST_CHANGEME' and password == 'MUST_CHANGEME'
  end

  # Check Chef Client File
  def client_file(fqdn)
    File.exists?("#{NODES_LOCATION}/#{fqdn}")
  end

  # Check Chef Node JSON file
  def node_file(fqdn)
    File.exists?("#{NODES_LOCATION}/#{fqdn}.json")
  end

  # Delete Chef Client file and Chef Client 
  def client_delete(fqdn)
    File.delete("#{NODES_LOCATION}/#{fqdn}") if client_file(fqdn)
    status = %x[knife client delete #{fqdn} -y 2>1]
    if status =~ /Cannot load client/
      true
    else
      $?.success?
    end
  end

  # Delete Chef Node file and Chef Node 
  def node_delete(fqdn)
    File.delete("#{NODES_LOCATION}/#{fqdn}.json") if node_file(fqdn)
    status = %x[knife node delete #{fqdn} -y 2>1 ]
    if status =~ /not found/
      true
    else
      $?.success?
    end
  end

  # Chef Client Create
  def client_create(fqdn)
    %x[knife client create #{fqdn} --disable-edit -f #{NODES_LOCATION}/#{fqdn} -VV]
    $?.success?
  end

  # Chef Node Create
  def node_create(env, fqdn, run_list)
    # e.g. run_list=role[role_name],recipe[recipe_name],role[role_name],..
    data = {
      'name' => fqdn,
      'chef_environment' => env,
      'normal' => {
      'tags' => []
    },
      'run_list' => run_list.split(',')
    }
    begin
      File.open("#{NODES_LOCATION}/#{fqdn}.json", "w") do |f|
        f.write JSON.pretty_generate(data)
      end
      %x[knife node from file "#{NODES_LOCATION}/#{fqdn}.json"]
      $?.success?
    rescue => error
      false
    end
  end

  # DELETE Chef Node and Client 
  delete '/node' do
    msg = []
    error = []
    if client_delete(params[:fqdn])
      msg.push "client deleted"
    else
      error.push "client delete failed"
    end

    if node_delete(params[:fqdn])
      msg.push "node deleted"
    else
      error.push "node deleted failed"
    end

    if error.empty?
      body "#{msg.join(', ')} \n"
    else
      body "msg=#{msg.join(', ')}, error=#{error.join(', ')} \n"
    end
  end

  # Get Chef Client PEM file
  get '/node' do
    if node_file(params[:fqdn])
      file = File.join(NODES_LOCATION, params[:fqdn])
      send_file(file, :filename => params[:fqdn])
    else
      status HTTP_ERROR_RESPONSE
      body "node does not exists \n"
    end
  end

  # Create Chef Node and Client, Returns Client PEM file
  post '/node' do
    if not (params[:env] and params[:fqdn] and params[:role])
      status HTTP_ERROR_RESPONSE
      body "must define fqdn, role and env options"
    elsif client_file(params[:fqdn]) or node_file(params[:fqdn])
      status HTTP_ERROR_RESPONSE
      body "run DELETE action, client or node file exists \n"
    else
      if client_create(params[:fqdn])
        if node_create(params[:env], params[:fqdn], params[:role])
          file = File.join(NODES_LOCATION, params[:fqdn])
          send_file(file, :filename => params[:fqdn])
        else
          status HTTP_ERROR_RESPONSE
          body "failed to create node.json run_list \n"
        end
      else
        status HTTP_ERROR_RESPONSE
        body "failed to create client certificate, client may already exists\n"
      end
    end
  end
end

# Webrick Options, with SSL. Change Options Accordingly

webrick_options = {
  :Port               => 6000,
  :Logger             => WEBrick::Log::new($stderr, WEBrick::Log::INFO),
  :SSLEnable          => true,
  :DocumentRoot       => "./nodes",
  :SSLVerifyClient    => OpenSSL::SSL::VERIFY_PEER,
  :SSLCertificate     => OpenSSL::X509::Certificate.new(  File.open(File.join(SSL_CERT_LOCATION, "server.crt")).read),
  :SSLPrivateKey      => OpenSSL::PKey::RSA.new(          File.open(File.join(SSL_CERT_LOCATION, "server.key")).read),
  :SSLCACertificateFile => File.join(SSL_CERT_LOCATION, "ca.crt"),
  :SSLCertName        => [ [ "CN",WEBrick::Utils::getservername ] ],
  # For some reasons SSLVerifyDepth does not seems to be working
  :SSLVerifyDepth     => 1
}

# Start Webrick Server
Rack::Handler::WEBrick.run SinatraChefNode, webrick_options

# TODO:
# Use Chef::Knife module to make knife calls instead of knife binary command line tool
