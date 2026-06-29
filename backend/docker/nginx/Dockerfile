FROM nginx:alpine

# Remove default config
RUN rm /etc/nginx/conf.d/default.conf

# Copy Laravel public dir + custom config.
# public/storage is a reparse point (symlink to ../storage/app/public); it's
# excluded via backend/.dockerignore since BuildKit refuses reparse points.
COPY ./public /var/www/html/public
COPY ./docker/nginx/default.conf /etc/nginx/conf.d/default.conf
