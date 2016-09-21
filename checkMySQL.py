#!/usr/bin/env python
#coding: utf-8

import os
import sys
import getopt
import subprocess
import pymysql.cursors


dbhost='localhost'
dbport=3306
dbuser='root'
dbpassword='mysql'


def run_cmd(cmd):
    p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    ret_str = p.stdout.read()
    p.wait()
    return ret_str


class InstanceMySQL(object):
    def __init__(self, host=None, port=None, user=None, passwd=None):
        self.dbhost = host
        self.dbport = port
        self.dbuser = dbuser
        self.dbpassword = dbpassword

    def connect(self):
        try:
            conn = pymysql.connect(self.dbhost, self.dbuser, self.dbpassword, port=self.dbport, charset='utf8')
            cur = conn.cursor()
            cur.close()
            conn.close()
        except Exception, e:
            print(e)
            return 1
        return 0

    def isHaveMySQL(self):
        #print self.connect()
        mysqldNum = run_cmd("ps -ef | egrep -i mysqld | grep %s | egrep -iv mysqld_safe | grep -v grep | wc -l" % self.dbport)
        mysqlPortNum = run_cmd("ss -tunlp | grep \":%s\" | wc -l" % self.dbport)
        #print mysqldNum,mysqlPortNum
        if ( int(mysqldNum) <= 0 ):
            print("error")
            return 1
        if ( int(mysqldNum) > 0 and  int(mysqlPortNum) <= 0 ):
            return 1
        if (self.connect()):
            return 1
        return 0


def CheckMySQL():
    try:
        shortargs='h:P:'
        longopts='help'
        opts, args=getopt.getopt(sys.argv[1:],shortargs, longopts=[longopts])
        if not opts:
            print('Usage: checkMySQL.py [OPTIONS]')
            print('  -h     Connect to host.')
            print('  -P     Port number to use for connection.')
            sys.exit(1)
        
        for opt, value in opts:
            if opt=='-h':
                dbhost=value
            elif opt=='-P':
                dbport=int(value)
            elif opt=='--help':
                print('Usage: checkMySQL.py [OPTIONS]')
                print('  -h     Connect to host.')
                print('  -P     Port number to use for connection.')
                sys.exit(1)
    except Exception, e:
        print(e)
        print('Usage: checkMySQL.py [OPTIONS]')
        print('  -h     Connect to host.')
        print('  -P     Port number to use for connection.')
        sys.exit(1)
    db = InstanceMySQL(dbhost, dbport, dbuser, dbpassword)
    st = db.isHaveMySQL()
    return st

if __name__== "__main__":
	st=CheckMySQL()
	sys.exit(st)
