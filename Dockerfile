# Bazowy obraz WordPress
FROM wordpress:latest

# Ustaw katalog roboczy
WORKDIR /var/www/html

# Instalacja WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Ustawienie właściciela plików
RUN chown -R www-data:www-data /var/www/html

# Opcjonalnie: expose port 80 (Compose już mapuje porty)
EXPOSE 80
