FROM nginx:alpine

# Remove default config
RUN rm /etc/nginx/conf.d/default.conf

# Copy Laravel public dir + custom config
COPY ./public /var/www/html/public
COPY ./docker/nginx/default.conf /etc/nginx/conf.d/default.conf
