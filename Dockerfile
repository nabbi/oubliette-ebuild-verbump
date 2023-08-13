# name the portage image
FROM gentoo/portage:latest as portage

# based on stage3 image
FROM gentoo/stage3:latest

# copy the entire portage volume in
COPY --from=portage /var/db/repos/gentoo /var/db/repos/gentoo

# package depends
RUN emerge -qv app-eselect/eselect-repository dev-vcs/git \
    sys-process/cronie net-misc/curl dev-util/pkgcheck

# oubliette overlay package depends
RUN eselect repository enable oubliette && \
    emaint sync -r oubliette
RUN emerge -qv app-misc/jq

# copy the ebuild version bump script
RUN mkdir /opt/oubliette-ebuild-verbump
COPY *.sh /opt/oubliette-ebuild-verbump

COPY crontab /etc/cron.d/oubliette-ebuild-verbump
CMD ["crond", "-f"]
