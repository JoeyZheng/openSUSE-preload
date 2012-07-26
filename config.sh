#!/bin/bash
#================
# FILE          : config.sh
#----------------
# PROJECT       : OpenSuSE KIWI Image System
# COPYRIGHT     : (c) 2006 SUSE LINUX Products GmbH. All rights reserved
#               :
# AUTHOR        : Marcus Schaefer <ms@suse.de>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : configuration script for SUSE based
#               : operating systems
#               :
#               :
# STATUS        : BETA
#----------------
#======================================
# Functions...
#--------------------------------------
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

#======================================
# Greeting...
#--------------------------------------
echo "Configure image: [$kiwi_iname]..."

#==========================================
# remove unneeded packages
#------------------------------------------
suseRemovePackagesMarkedForDeletion

#======================================
# Clean up languages
#--------------------------------------

# all removed files will result in one language less shown during firstboot.
# only English (EN), Traditional Chinese (TC), 
# Simplified Chinese (SC)

(
cd /usr/share/YaST2/data/languages/
rm language_af_ZA.ycp language_bg_BG.ycp language_bn_BD.ycp language_bs_BA.ycp
rm language_ca_ES.ycp language_cy_GB.ycp language_ko_KR.ycp language_et_EE.ycp
rm language_gl_ES.ycp language_gu_IN.ycp language_he_IL.ycp language_hi_IN.ycp
rm language_hr_HR.ycp language_id_ID.ycp language_ka_GE.ycp language_km_KH.ycp
rm language_lt_LT.ycp language_mk_MK.ycp language_mr_IN.ycp language_nn_NO.ycp
rm language_pa_IN.ycp language_ar_EG.ycp language_ro_RO.ycp language_si_LK.ycp
rm language_sk_SK.ycp language_sl_SI.ycp language_sr_RS.ycp language_ta_IN.ycp
rm language_th_TH.ycp language_ja_JP.ycp language_uk_UA.ycp language_vi_VN.ycp
rm language_wa_BE.ycp language_xh_ZA.ycp language_zu_ZA.ycp

# language_pt_PT.ycp language_cs_CZ.ycp language_da_DK.ycp language_de_DE.ycp
# language_es_ES.ycp language_fi_FI.ycp
# language_fr_FR.ycp language_hu_HU.ycp language_it_IT.ycp language_el_GR.ycp
# language_tr_TR.ycp language_nb_NO.ycp language_nl_NL.ycp language_pl_PL.ycp
# language_pt_BR.ycp language_ru_RU.ycp language_sv_SE.ycp
# thus remaining:
# language_en_GB.ycp language_en_US.ycp language_zh_CN.ycp language_zh_TW.ycp  
#
# which contains above mentioned languages and additional English (US)
)

#======================================
# Enable firstboot
#--------------------------------------
touch /var/lib/YaST2/reconfig_system

#======================================
# SuSEconfig
#--------------------------------------
suseConfig

#======================================
# gnomeify windowmanager and displaymanager
#======================================
sed -i 's/^DISPLAYMANAGER=.*/DISPLAYMANAGER="gdm"/' /etc/sysconfig/displaymanager
sed -i 's/^DEFAULT_WM=.*/DEFAULT_WM="gnome"/' /etc/sysconfig/windowmanager
sed -i 's/^X_MOUSE_CURSOR=.*/X_MOUSE_CURSOR="DMZ"/' /etc/sysconfig/windowmanager

#======================================
# SuSEfirewall2: enable sshd by default
#======================================
sed -i 's/^FW_CONFIGURATIONS_EXT=.*/FW_CONFIGURATIONS_EXT="sshd"/' /etc/sysconfig/SuSEfirewall2

#======================================
# scim setup
#======================================

# disable scim for all languages
for lang in `find /etc/X11/xim.d/ -mindepth 1 -maxdepth 1 -type d`
do
  ln -s ../none $lang/40-none
done

# enable scim again for some languages
for lang in zh_CN zh_TW
do
  rm -f /etc/X11/xim.d/$lang/40-none
done

# set default IMs for zh_TW (ZhuYin) and zh_CN (Smart Pinyin)
# also for russian and arabic keyboard layout
# Show typing-method icon as default for JP Anthy
echo "/DefaultIMEngineFactory/zh_CN = 05235cfc-43ce-490c-b1b1-c5a2185276ae
/DefaultIMEngineFactory/zh_TW = a93845cd-6e00-44fc-8928-22d2590bbb61
/DefaultIMEngineFactory/ru_RU = IMEngine-M17N-ru-kbd
/DefaultIMEngineFactory/ar_AR = IMEngine-M17N-ar-kbd
/IMEngine/Anthy/ShowTypingMethodLabel = true" >> /etc/scim/config

#=============================================
# Set default runlevel to 5
#=============================================
sed -i -e's/^id:3:/id:5:/' /etc/inittab

#======================================
# Umount kernel filesystems
#--------------------------------------
baseCleanMount

exit 0
