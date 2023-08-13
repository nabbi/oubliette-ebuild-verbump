# name the portage image
FROM gentoo/portage:latest as portage

# based on stage3 image
FROM gentoo/stage3:latest as gentoo

# copy the entire portage volume in
COPY --from=portage /var/db/repos/gentoo /var/db/repos/gentoo

# package depends
RUN emerge -qv app-eselect/eselect-repository dev-vcs/git \
    sys-process/cronie net-misc/curl dev-util/pkgcheck \
    app-misc/jq

# copy the ebuild version bump script
RUN mkdir /opt/oubliette-ebuild-verbump
COPY *.sh /opt/oubliette-ebuild-verbump

COPY crontab /etc/cron.d/oubliette-ebuild-verbump

# strip image
RUN rm -r /var/db/repos/ /usr/share/doc/ /usr/share/man/
FROM scratch
COPY --from=gentoo / /

CMD ["crond", "-f"]
