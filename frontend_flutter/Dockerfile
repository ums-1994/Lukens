# --- Build Flutter Web ---
FROM debian:stable AS build

RUN apt-get update && apt-get install -y curl git unzip xz-utils zip libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/flutter/flutter.git -b stable /flutter
ENV PATH="/flutter/bin:/flutter/bin/cache/dart-sdk/bin:${PATH}"

RUN flutter config --enable-web

# Copy only the Flutter frontend project into the build context
WORKDIR /app
COPY frontend_flutter/ .

RUN flutter pub get
RUN flutter build web --release


# --- Serve using Nginx ---
FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
