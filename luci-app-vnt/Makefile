include $(TOPDIR)/rules.mk

PKG_VERSION:=2.0.0
PKG_NAME:=vnt

# 架构映射保持不变
ifeq ($(ARCH),mipsel)
	APP_ARCH:=mipsel-unknown-linux-musl
endif
ifeq ($(ARCH),mips)
	APP_ARCH:=mips-unknown-linux-musl
endif
ifeq ($(ARCH),arm)
	APP_ARCH:=arm-unknown-linux-musleabi
endif
ifeq ($(BOARD),kirkwood)
	APP_ARCH:=arm-unknown-linux-musleabi
endif
ifeq ($(ARCH),armv7)
	APP_ARCH:=armv7-unknown-linux-musleabi
endif
ifeq ($(ARCH),aarch64)
	APP_ARCH:=aarch64-unknown-linux-musl
endif
ifeq ($(ARCH),arm64)
	APP_ARCH:=aarch64-unknown-linux-musl
endif
ifeq ($(ARCH),armv8)
	APP_ARCH:=aarch64-unknown-linux-musl
endif
ifeq ($(ARCH),i386)
	APP_ARCH:=i686-unknown-linux-musl
endif
ifeq ($(ARCH),x86_64)
	APP_ARCH:=x86_64-unknown-linux-musl
endif

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=net
	CATEGORY:=Network
	TITLE:=An efficient VPN vnt2 (client&server all-in-one)
	DEPENDS:=@(i386||x86_64||arm||aarch64||mipsel||mips) +kmod-tun
	URL:=https://github.com/vnt-dev/vnt
endef

define Package/$(PKG_NAME)/description
  简便高效的异地组网、内网穿透工具vnt2，客户端服务端二合一
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	cd $(PKG_BUILD_DIR)
	# 适配新版vnt2包名、zip格式
	ZIP_FILE=vnt2-$(APP_ARCH)-v$(PKG_VERSION).zip
	[ ! -f $${ZIP_FILE} ] && wget --timeout=60 --tries=5 https://github.com/vnt-dev/vnt/releases/download/v$(PKG_VERSION)/$${ZIP_FILE} -O $${ZIP_FILE}
	# 替换tar解压为unzip
	unzip -o $${ZIP_FILE}
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
	# vnt2合并后统一二进制名为vnt，不再区分vnt-cli/vnts
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/vnt $(1)/usr/bin/vnt
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
