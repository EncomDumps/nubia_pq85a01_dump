#!/system/bin/sh
# Copyright (c) 2009, ZTE . All rights reserved.
#History:
#when       who         what, where, why
#--------   ----        ---------------------------------------------------
#2009-12-24 zhangxian   new file for bt test mode
##########################################

#
#normally bluetooth RF dut(device under test) for bluedroid
#
btconfig /dev/smd3 rawcmd 0x03, 0x0003
btconfig /dev/smd3 rawcmd 0x06, 0x03
btconfig /dev/smd3 rawcmd 0x03, 0x05, 0x02, 0x00, 0x02
btconfig /dev/smd3 rawcmd 0x03, 0x1A, 0x03
btconfig /dev/smd3 rawcmd 0x03, 0x20, 0x00
btconfig /dev/smd3 rawcmd 0x03, 0x22, 0x00
