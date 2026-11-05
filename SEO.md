# Care500 search and answer-engine foundations

## Implemented
- Descriptive title and meta description.
- Canonical homepage URL.
- Open Graph and X/Twitter summary metadata.
- Organization JSON-LD structured data.
- robots.txt and XML sitemap.
- Plain-text sitemap for simple crawler discovery.
- llms.txt with a cautious, privacy-aware description.

## Temporary indexing safeguard
The homepage currently includes prototype figures and illustrative case/payment records. The HTML therefore uses `noindex,follow` until those items are replaced with verified live records and the service's operational claims are confirmed. Do not remove this safeguard merely to force indexing.

## Before enabling indexing
1. Replace all illustrative figures, case cards, and ledger rows with verified live data or remove them.
2. Confirm the public product description, legal/operator identity, contact details, payment status, eligibility and allocation rules.
3. Add real, useful pages for About, How it works, Eligibility, FAQs, Trust and safety, Privacy, Terms, and Contact. Do not publish thin doorway pages.
4. Add unique title, description, canonical URL, and appropriate structured data to each indexable page.
5. Add real social-share imagery with correct dimensions and alt text.
6. Remove the noindex meta directive only after the above checks pass.
7. Submit https://care500.vercel.app/sitemap.xml in Google Search Console and inspect indexing and rich-result reports.
8. Monitor Search Console queries, crawl errors, Core Web Vitals, and actual user journeys.

## SEO, AEO and AI discovery
There is no special HTML tag that guarantees AEO, AIO, LLM citations, or Google rankings. Prioritise useful first-party explanations, clear headings, concise answers to real user questions, accessible semantic HTML, fast mobile performance, transparent authorship and evidence, and consistent organisation details. Keep structured data accurate and visible page content consistent with it.

## Sitemap maintenance
Update sitemap.xml and sitemap.txt when genuine public pages are added. Include only canonical, indexable URLs that return HTTP 200. Do not include private admin, donor, patient, API, payment, or query-string URLs.
