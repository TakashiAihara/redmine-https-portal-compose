# quote https://qiita.com/bezeklik/items/b9d75ee74e0ae4c6d42c

mkdir --parents --verbose /srv/redmine/config

cat << "_EOF_" > /srv/redmine/config/additional_environment.rb
config.cache_store = :mem_cache_store, "memcached"
_EOF_

echo "gem 'dalli'" >> /srv/redmine/Gemfile.local

cp .env /srv/redmine/

docker network create nginx-proxy

docker-compose --project-directory /srv/redmine up -d


NETWORK=$(docker container inspect redmine --format='{{.HostConfig.NetworkMode}}') && \
GATEWAY=$(docker network inspect ${NETWORK} --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}') && \
cat << _EOF_ > /srv/redmine/config/configuration.yml
default:
  email_delivery:
    delivery_method: :smtp
    smtp_settings:
      address: ${GATEWAY}
      port: 25
      domain: redmine.example.jp
_EOF_


sleep 600
docker exec redmine bundle exec rake redmine:load_default_data RAILS_ENV=production REDMINE_LANG=ja

docker exec redmine passenger-config restart-app /usr/src/redmine
