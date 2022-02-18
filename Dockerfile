############################################################################
### We use alpine as our base image to download the latest waterfall.jar ###
############################################################################
FROM docker.io/library/alpine:latest AS downloader

#################
### Arguments ###
#################
ARG WATERFALL_PROJECTNAME=waterfall
ARG WATERFALL_VERSION=1.18

#####################
### Install tools ###
#####################
RUN apk add --no-cache curl jq

##########################
### Download waterfall ###
##########################
RUN WATERFALL_BUILDS_URL=https://papermc.io/api/v2/projects/${WATERFALL_PROJECTNAME}/versions/${WATERFALL_VERSION} && \
	WATERFALL_BUILD=$(curl ${WATERFALL_BUILDS_URL} | jq -r '.builds[-1]') && \
	echo "### Latest build for Waterfall v${WATERFALL_VERSION} is ${WATERFALL_BUILD}" && \
	WATERFALL_FILES_URL=https://papermc.io/api/v2/projects/${WATERFALL_PROJECTNAME}/versions/${WATERFALL_VERSION}/builds/${WATERFALL_BUILD} && \
	WATERFALL_JAR=$(curl ${WATERFALL_FILES_URL} | jq -r '.downloads.application.name') && \
	WATERFALL_DOWNLOAD_URL=https://papermc.io/api/v2/projects/${WATERFALL_PROJECTNAME}/versions/${WATERFALL_VERSION}/builds/${WATERFALL_BUILD}/downloads/${WATERFALL_JAR} && \
	echo "### Downloading Waterfall from ${WATERFALL_DOWNLOAD_URL}" && \
	curl --silent --location --output /waterfall.jar ${WATERFALL_DOWNLOAD_URL}

################################
### We use a java base image ###
################################
FROM docker.io/library/openjdk:17

###################
### Environment ###
###################
ENV WATERFALL_PATH=/opt/waterfall

ENV SERVER_PATH=${WATERFALL_PATH}/server
ENV CONFIG_PATH=${WATERFALL_PATH}/config

########################
### Import waterfall ###
########################
COPY --from=downloader /waterfall.jar ${SERVER_PATH}/waterfall.jar

#########################
### Working directory ###
#########################
WORKDIR ${SERVER_PATH}

########################
### Obtain starth.sh ###
########################
ADD scripts/docker-entrypoint.sh .
RUN chmod +x docker-entrypoint.sh

############
### User ###
############
RUN /usr/sbin/groupadd --gid 2756 waterfall && \
    /usr/sbin/useradd -ms /bin/bash waterfall -u 2756 -g waterfall -d ${SERVER_PATH} && \
    mkdir ${CONFIG_PATH} ${SERVER_PATH}/logs ${SERVER_PATH}/plugins && \
    chown waterfall $WATERFALL_PATH -R

USER waterfall

###################
### Preparation ###
###################
# Create symlinks for configs
RUN ln -s $CONFIG_PATH/config.yml $SERVER_PATH/config.yml && \
  ln -s $CONFIG_PATH/locations.yml $SERVER_PATH/locations.yml && \
  ln -s $CONFIG_PATH/waterfall.yml $SERVER_PATH/waterfall.yml

###############
### Volumes ###
###############
VOLUME "${SERVER_PATH}/logs"
VOLUME "${SERVER_PATH}/plugins"
VOLUME "${CONFIG_PATH}"

#############################
### Expose minecraft port ###
#############################
EXPOSE 25565

######################################
### Entrypoint is the start script ###
######################################
ENTRYPOINT [ "./docker-entrypoint.sh" ]

CMD [ "serve" ]
