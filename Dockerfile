# 베이스 이미지: 공식 nginx
FROM nginx:latest

# 환경 변수 기본값.
# Compose 나 docker run -e 로 덮어쓸 수 있으며, 덮어쓰지 않으면 이 값이 쓰인다.
ENV NGINX_PORT=80
ENV APP_MODE=development

# 정적 페이지 배치.
# 빌드 컨텍스트가 저장소 루트이므로 상대 경로로 참조한다.
COPY index.html /usr/share/nginx/html/index.html

# nginx 공식 이미지는 기동 시 /etc/nginx/templates/*.template 을 envsubst 로 치환해
# /etc/nginx/conf.d/ 로 출력한다. 덕분에 이미지를 다시 빌드하지 않고
# 환경 변수만으로 리슨 포트를 바꿀 수 있다.
COPY default.conf.template /etc/nginx/templates/default.conf.template

# EXPOSE 는 문서화 목적이며 실제 포트 공개는 -p / ports 설정이 담당한다.
EXPOSE ${NGINX_PORT}
