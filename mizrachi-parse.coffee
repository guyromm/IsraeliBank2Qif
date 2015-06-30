#!/usr/bin/env coffee
cheerio = require 'cheerio'
qif = require 'qif'
l = console.log

mode = process.argv[2]
allowed_modes = ['mizrahi-checking','mizrahi-credit','poalim-checking','isracard']
if mode not in allowed_modes then throw "must specify mode, one of "+allowed_modes
datergs =
        'mizrahi-credit':new RegExp '^([0-9]{4})\-([0-9]{2})\-([0-9]{2})$'
        'mizrahi-checking':new RegExp '^([0-9]{2})/([0-9]{2})/([0-9]{2})$'
        'poalim-checking': '^([0-9]{2})/([0-9]{2})/([0-9]{4})$'
        'isracard': '^([0-9]{2})/([0-9]{2})/([0-9]{4})$'
codings =
        'mizrahi-checking':'ucs-2'
        'mizrahi-credit':'ucs-2'
        'poalim-checking':'utf-8' #wrong! iso8859-8. convert yourself.
        'isracard':'utf-8' #wrong! iso8859-8. convert yourself.
        
returned=''
process.stdin.setEncoding codings[mode]

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
poalim_checking_trans =
        0: 'date'
        1: 'payee'
        2: 'checknumber'
        3: 'value_date'
        4: 'withdrawal_amount'
        5: 'deposit_amount'
        6: 'balance'
isracard_trans =
        0: 'date'
        1: 'payee'
        2: 'local_amount'
        3: 'amount'
        4: 'checknumber'
        5: 'memo'
isracard_abroad_trans =
        0: 'date'
        1: 'purchase_date'
        2: 'payee'
        3: 'city'
        4: 'origin_currency'
        5: 'local_amount'
        6: 'charge_currency'
        7: 'amount'
        8: 'checknumber'
trans =
        "mizrahi-credit":credit_trans
        "mizrahi-checking":checking_trans
        "poalim-checking":poalim_checking_trans
        "isracard":isracard_trans

# poalim usage: iconv -f iso8859-8 2015-03-30-2015-06-30.xls |  ./mizrachi-parse.coffee poalim-checking

transform = ($, dts, mtrans) ->
        charge = {}
        dts.each (tdidx,td) ->
                #l 'sel',tdidx,$(td).text()
                charge[mtrans[tdidx]] = $(td).text().trim()
        charge

process.stdin.on 'end', ->
        #l 'have read',returned.length,'bytes.'
        $ = cheerio.load returned
        transactions = {cash:[]}
        $('tr').each (idx,el) ->
                #l 'got a row',el
                dts = $(el).find 'td'
                charge = transform $,dts,trans[mode]
                if mode=='isracard' and (charge.payee and charge.payee.match datergs[mode])
                        #throw "argh! isracard type two; '"+(charge.date.match charge.payee)+"'"
                        charge = transform $, dts, isracard_abroad_trans

                dateres = charge.date.match datergs[mode] if charge.date
                if dateres
                        if mode in ['mizrahi-credit','isracard']
                                charge.local_amount=parseFloat(charge.local_amount.replace(',',''))*-1
                                charge.amount=parseFloat(charge.amount.replace(',',''))*-1
                        else if mode in ['poalim-checking','mizrahi-checking']
                                if charge.withdrawal_amount
                                        charge.amount=parseFloat(charge.withdrawal_amount.replace(',',''))*-1
                                else if charge.deposit_amount
                                        charge.amount=parseFloat(charge.deposit_amount.replace(',',''))
                                else
                                        throw "wtf. not a deposit and not a withdrawal? "+charge.withdrawal_amount+" / "+charge.deposit_amount
                        else throw "unknown mode "+mode

                        #process.stderr.write 'inserting '+charge.date+' '+charge.payee+' '+charge.local_amount+' '+charge.amount+' '+charge.memo+'\n
                        transactions.cash.push charge
                else
                        process.stderr.write 'discarding '+charge.date+' '+charge.payee+' '+charge.local_amount+' '+charge.amount+' '+charge.memo+'\n'
        qifData = qif.write transactions
        console.log qifData
