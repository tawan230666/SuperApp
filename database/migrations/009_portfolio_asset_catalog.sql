-- Curated identities, not generated securities. Prices remain synthetic fixtures.
-- https://www.set.or.th/en/market/product/stock/quote/ptt/company-profile/information
-- https://www.set.or.th/en/market/product/etf/quote/tdex/factsheet
-- Initial Phase 5 test symbols remain as historical references, not tradable assets.
UPDATE assets SET active=false,updated_at=now() WHERE symbol IN ('PAPER-STOCK','PAPER-ETF');
INSERT INTO assets(symbol,name,type,exchange,currency,country,sector,industry) VALUES
 ('PTT','PTT PUBLIC COMPANY LIMITED','STOCK','SET','THB','TH','Energy','Energy & Utilities'),
 ('TDEX','THAIDEX SET50 EXCHANGE TRADED FUND','ETF','SET','THB','TH','Diversified','Index ETF');
