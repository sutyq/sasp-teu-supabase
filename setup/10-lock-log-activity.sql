-- =====================================================
-- SASP TEU — Zamknutí log_activity()
-- =====================================================
-- log_activity() je trigger funkce (security definer), která zapisuje do
-- activity_log. Dřív měla právo EXECUTE i anon/authenticated a neměla pevný
-- search_path. Triggery běží i bez tohoto práva (EXECUTE se u triggeru kontroluje
-- jen při jeho vytvoření), takže zápis do logu funguje dál.
-- Už nasazeno jako migrace lock_log_activity. Bezpečné spustit opakovaně.
-- =====================================================

revoke execute on function public.log_activity() from public, anon, authenticated;
alter function public.log_activity() set search_path = public;
