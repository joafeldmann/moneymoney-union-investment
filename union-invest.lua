
--
-- MoneyMoney Web Banking Extension
-- http://moneymoney-app.com/api/webbanking
--
--
-- The MIT License (MIT)
--
-- Copyright (c) 2014 Joachim Feldmann (joafeldmann)
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
--
-- Get balance and transactions for UNION INVESTMENT FONDS
--

WebBanking{version    = 1.0,
           country    = "de",
           services   = { "Union Investment" }}


local connection
local html
local baseUrl = "https://privatkunden.union-investment.de/process"

--
-- Utils
--

local function strToDate (str)
  local d, m, y = string.match(str, "(%d%d)%.(%d%d)%.(%d%d%d%d)")
  if d and m and y then
    return os.time{year=y, month=m, day=d}
  end
end

local function strToAmount (str)
  -- Helper function for converting localized amount strings to Lua numbers.
  str = string.gsub(string.gsub(str, "[^%d,-]", ""), ",", ".")
  if string.match(str, "-") then
    str = "-" .. string.gsub(str, "-", "")
  end
  return tonumber(str)
end


--
-- MoneyMoney API
--


function SupportsBank (protocol, bankCode)
  return true  -- Support any bank.
end


function InitializeSession (protocol, bankCode, username, username2, password, username3)
  
  connection = Connection()

  -- Fetch login page.
  html = HTML(connection:get(baseUrl .. "?action=showLogin"))

  -- Fill in login credentials
  html:xpath("//input[@name='user']"):attr("value", username)
  html:xpath("//input[@name='pin']"):attr("value", password)

  -- Submit login form
  html = HTML(connection:request(html:xpath("//form[@name='login']"):submit()))

  -- Follow redirect
  html = HTML(connection:get(baseUrl .. "?action=init"))

  if html:xpath("//table[@class='logged-in']"):length() == 0 then
    return "Oops!"
  end

end




function ListAccounts (knownAccounts)

  local accounts = {}

  -- Extract owner name
  local owner = html:xpath('//*[@id="contentC"]/div[2]/table[1]/tbody/tr/td[1]'):text()
  owner = string.gsub(owner, "Angemeldet als:", "")

  -- Extract depot base id
  local depot = html:xpath('//*[@id="contentC"]/div[2]/table[1]/tbody/tr/td[2]'):text()
  depot = string.gsub(depot, "Aktuelles Depot:", "")

  html:xpath('//*[@id="contentC"]/div[2]/table[2]/tbody/tr[position()>1][position()<last()]'):each(function (index, tr)
       
    local tds = tr:children()
    local accountNumber = tds:get(1):text()
    local name = tds:get(2):text()

    if string.len(accountNumber) > 0 then
      local account = {
        name          = name,
        accountNumber = depot .. "-" .. accountNumber,
        owner         = owner,
        currency      = "EUR",
        type          = AccountTypePortfolio
      }
      table.insert(accounts, account)
    end

  end)

  return accounts
end



function RefreshAccount (account, since)
  local balance
  local transactions = {}

  -- Extract depot base id
  local depot = html:xpath('//*[@id="contentC"]/div[2]/table[1]/tbody/tr/td[2]'):text()
  depot = string.gsub(depot, "Aktuelles Depot:", "")
  depot = string.gsub(depot, "^%s*(.-)%s*$", "%1")

  -- Locate account in list of accounts (Website I).
  html:xpath('//*[@id="contentC"]/div[2]/table[2]/tbody/tr[position()>1][position()<last()]'):each(function (index, tr)
    local tds = tr:children()    
    local accountNumber = depot .. "-" .. tds:get(1):text()
    local name = tds:get(2):text()

    if accountNumber == account.accountNumber then

      -- Extract balance
      balance = tds:get(5):text();
      balance = string.sub(balance, string.find(balance, "%S+"));
      balance = strToAmount(balance)

      local tHtml = HTML(connection:get(baseUrl .. "?action=showOrdersSummary&UDid=" .. index-1 ))

      -- Traverse list of transactions
      tHtml:xpath('//*[@id="contentC"]/div[2]/table[2]//tr[position()>1]'):each(function (index, tr)
        
        local tds = tr:children()

        -- Create transaction object
        -- local transaction = {          
        --   bookingDate = strToDate(tds:get(1):text()),
        --   valueDate   = strToDate(tds:get(1):text()),
        --   name        = tds:get(2):text(),
        --   amount      = amount,
        --   purpose     = "Preis: " .. tds:get(4):text()
        -- }
         local transaction = {          
          currency    = "EUR",
          bookingDate = strToDate(tds:get(1):text()),
          valueDate   = strToDate(tds:get(1):text()),
          name        = tds:get(2):text(),
          amount      = strToAmount(tds:get(5):text()),
          price       = strToAmount(tds:get(4):text())
        }
        table.insert(transactions, transaction)

      end)

    end
    
  end)

  return {balance=balance, transactions=transactions}
end


function EndSession ()
  HTML(connection:get(baseUrl .. "?action=logout"))
end
