#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
connect="$script_dir/anki-connect.sh"

offline() {
    jq -cn --arg reason "${1:-Abra o Anki para ver a sessão de hoje}" '{
      available:false,
      seeded:false,
      text:"󰓎",
      class:"offline",
      tooltip:$reason,
      total:0,
      new:0,
      learn:0,
      review:0,
      reviewed_today:0,
      k8s:0,
      gpu:0,
      french:0
    }'
}

if ! decks_response=$("$connect" request deckNames 2>/dev/null); then
    offline
    exit 0
fi

if ! jq -e '.result | index("Study Hub") != null' >/dev/null 2>&1 <<<"$decks_response"; then
    offline 'Abra o Study Hub para preparar os baralhos iniciais'
    exit 0
fi

decks='{"decks":["Study Hub","Study Hub::Kubernetes Core","Study Hub::NVIDIA GPUs on Kubernetes","Study Hub::French Essentials"]}'
if ! stats_response=$("$connect" request getDeckStats "$decks" 2>/dev/null) \
    || ! reviewed_response=$("$connect" request getNumCardsReviewedToday 2>/dev/null); then
    offline
    exit 0
fi

jq -cn \
    --argjson stats "$(jq '.result' <<<"$stats_response")" \
    --argjson reviewed "$(jq '.result' <<<"$reviewed_response")" '
  def by_name($name):
    first($stats[] | select(
      .name == $name or (.name | endswith("::" + $name))
    )) // {
      new_count:0, learn_count:0, review_count:0, total_in_deck:0
    };
  def today($deck): $deck.new_count + $deck.learn_count + $deck.review_count;
  (by_name("Study Hub")) as $all |
  # Anki 25.x returns leaf names for subdecks even when queried by full path.
  (by_name("Kubernetes Core")) as $k8s |
  (by_name("NVIDIA GPUs on Kubernetes")) as $gpu |
  (by_name("French Essentials")) as $fr |
  (today($all)) as $total |
  {
    available:true,
    seeded:true,
    text:(if $total > 0 then "󰓎  \($total)" else "󰓎  ✓" end),
    class:(if $total > 0 then "due" else "clear" end),
    tooltip:(
      "Study Hub — sessão de hoje\n" +
      "Kubernetes: \(today($k8s)) · GPU: \(today($gpu)) · Français: \(today($fr))\n" +
      "Novos: \($all.new_count) · Aprendendo: \($all.learn_count) · Revisões: \($all.review_count)\n" +
      "Revistos hoje (todos os baralhos): \($reviewed)\n" +
      "Clique: estudar · botão direito: agente de estudos"
    ),
    total:$total,
    new:$all.new_count,
    learn:$all.learn_count,
    review:$all.review_count,
    reviewed_today:$reviewed,
    k8s:today($k8s),
    gpu:today($gpu),
    french:today($fr)
  }
'
