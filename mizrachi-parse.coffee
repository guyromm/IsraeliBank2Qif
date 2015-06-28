#!/usr/bin/env coffee
cheerio = require 'cheerio'
qif = require 'qif'
l = console.log

mode = process.argv[2]
if not mode then throw "must specify mode 'checking' or 'credit'"
datergs =
        'credit':new RegExp '^([0-9]{4})\-([0-9]{2})\-([0-9]{2})$'
        'checking':new RegExp '^([0-9]{2})/([0-9]{2})/([0-9]{2})$'

returned=''
process.stdin.setEncoding 'ucs-2'
process.stdin.on 'readable', ->
        chunk = process.stdin.read()
        if chunk != null
                cstr = chunk.toString()
                returned+=cstr
credit_trans =
        0: 'date'
        1: 'payee'
        2: 'local_amount'
        3: 'memo'
        4: 'amount'
checking_trans =
        0: 'date'
        1: 'value_date'
        2: 'payee'
        3: 'deposit_amount'
        4: 'withdrawal_amount'
        5: 'balance'
        6: 'checknumber'
trans =
        "credit":credit_trans
        "checking":checking_trans
              
process.stdin.on 'end', ->
        #l 'have read',returned.length,'bytes.'
        $ = cheerio.load returned
        transactions = {cash:[]}
        $('tr').each (idx,el) ->
                #l 'got a row',el
                charge = {}
                dts = $(el).find 'td'
                dts.each (tdidx,td) ->
                        #l 'sel',tdidx,$(td).text()
                        charge[trans[mode][tdidx]] = $(td).text().trim()
                dateres = charge.date.match datergs[mode] if charge.date
                if dateres
                        if mode == 'credit'
                                charge.local_amount=parseFloat(charge.local_amount.replace(',',''))*-1
                                charge.amount=parseFloat(charge.amount.replace(',',''))*-1
                        else if mode == 'checking'
                                if charge.withdrawal_amount
                                        charge.amount=parseFloat(charge.withdrawal_amount.replace(',',''))*-1
                                else if charge.deposit_amount
                                        charge.amount=parseFloat(charge.deposit_amount.replace(',',''))
                                else
                                        throw "wtf. not a deposit and not a withdrawal?"

                        #process.stderr.write 'inserting '+charge.date+' '+charge.payee+' '+charge.local_amount+' '+charge.amount+' '+charge.memo+'\n
                        transactions.cash.push charge
                else
                        process.stderr.write 'discarding '+charge.date+' '+charge.payee+' '+charge.local_amount+' '+charge.amount+' '+charge.memo+'\n'
        qifData = qif.write transactions
        console.log qifData
