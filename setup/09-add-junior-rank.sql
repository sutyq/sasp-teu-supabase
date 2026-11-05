-- =====================================================
-- SASP TEU — Hodnost Junior
-- =====================================================
-- Povolí hodnost Junior (nejnižší, pod Member). Bezpečné spustit opakovaně.
-- Už nasazeno jako migrace add_junior_rank.
-- =====================================================

alter table public.officers drop constraint if exists officers_rank_check;
alter table public.officers add constraint officers_rank_check
  check (rank in ('Junior', 'Member', 'Senior', 'CO', 'XO'));
