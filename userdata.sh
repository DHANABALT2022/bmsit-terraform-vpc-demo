#!/bin/bash
# EC2 user data: Apache web server with a BMSIT FDP welcome page (Amazon Linux 2023)

dnf install -y httpd
systemctl enable --now httpd

# Read instance details from the metadata service (IMDSv2)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
md() { curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/$1"; }

INSTANCE_ID=$(md instance-id)
AZ=$(md placement/availability-zone)
PRIVATE_IP=$(md local-ipv4)
INSTANCE_TYPE=$(md instance-type)
PUBLIC_IP=$(md public-ipv4)

# Public or private subnet? Decide the route shown on the page
if [[ "$PUBLIC_IP" =~ ^[0-9.]+$ ]]; then
  SUBNET="Public subnet"
  STOP1="Your browser"
  STOP2="Internet gateway"
else
  SUBNET="Private subnet"
  STOP1="Your laptop"
  STOP2="Bastion host"
fi

cat > /var/www/html/index.html <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Welcome | BMSIT FDP on AWS cloud</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,500;12..96,700&family=IBM+Plex+Sans:wght@400;500&family=IBM+Plex+Mono:wght@500&display=swap" rel="stylesheet">
<style>
  :root {
    --bg: #F3F6FA; --ink: #172B4D; --muted: #5B6B82; --rule: #D7DFEA;
    --line: #0F7B6C; --accent: #F2A900; --card: #FFFFFF;
    --display: "Bricolage Grotesque", "Segoe UI", system-ui, sans-serif;
    --body: "IBM Plex Sans", "Segoe UI", system-ui, sans-serif;
    --mono: "IBM Plex Mono", ui-monospace, Consolas, monospace;
  }
  * { box-sizing: border-box; margin: 0; }
  body { background: var(--bg); color: var(--ink); font: 400 1.0625rem/1.6 var(--body); min-height: 100vh; display: flex; flex-direction: column; }
  .wrap { width: min(1040px, 100% - 3rem); margin-inline: auto; }
  header { border-bottom: 1px solid var(--rule); }
  header .wrap { display: flex; justify-content: space-between; gap: 1rem; flex-wrap: wrap; padding-block: 1.1rem; font-size: .95rem; }
  header strong { font-weight: 500; }
  header span { color: var(--muted); }
  main { flex: 1; padding-block: clamp(3rem, 9vw, 6.5rem) 4rem; }
  h1 { font: 700 clamp(2.5rem, 6.5vw, 4.6rem)/1.02 var(--display); letter-spacing: -.025em; max-width: 14ch; }
  .lead { margin-top: 1.4rem; max-width: 56ch; font-size: 1.2rem; color: var(--muted); }

  .route { list-style: none; padding: 0; margin: 3.5rem 0 3rem; display: grid; grid-template-columns: repeat(4, 1fr); position: relative; }
  .route::before { content: ""; position: absolute; top: 11px; left: 12.5%; right: 12.5%; height: 4px; background: var(--line); border-radius: 2px; transform-origin: left; }
  .route li { position: relative; text-align: center; padding-top: 2.4rem; font-weight: 500; }
  .route li::before { content: ""; position: absolute; top: 0; left: 50%; translate: -50% 0; width: 26px; height: 26px; border-radius: 50%; background: var(--card); border: 4px solid var(--line); }
  .route li:last-child::before { border-color: var(--accent); background: var(--accent); box-shadow: 0 0 0 6px rgba(242,169,0,.25); }
  .route small { display: block; font-weight: 400; color: var(--muted); font-size: .9rem; }
  @media (prefers-reduced-motion: no-preference) {
    .route::before { animation: draw 1.4s cubic-bezier(.6,0,.2,1) .2s both; }
    .route li:last-child::before { animation: arrive .4s ease-out 1.5s both; }
    @keyframes draw { from { transform: scaleX(0); } to { transform: scaleX(1); } }
    @keyframes arrive { from { scale: .4; opacity: 0; } to { scale: 1; opacity: 1; } }
  }

  .server { background: var(--card); border: 1px solid var(--rule); border-left: 6px solid var(--accent); padding: 1.6rem 1.8rem; max-width: 640px; }
  .server h2 { font: 500 1.35rem/1.3 var(--display); margin-bottom: 1rem; }
  .server dl { display: grid; grid-template-columns: max-content 1fr; gap: .55rem 2rem; }
  .server dt { color: var(--muted); }
  .server dd { font-family: var(--mono); font-size: .98rem; overflow-wrap: anywhere; }
  .note { margin-top: 1rem; color: var(--muted); font-size: .95rem; max-width: 60ch; }

  footer { border-top: 1px solid var(--rule); padding-block: 1.2rem; color: var(--muted); font-size: .92rem; }

  @media (max-width: 640px) {
    .route { grid-template-columns: 1fr; gap: 1.6rem; margin-left: .2rem; }
    .route::before { top: 13px; bottom: 13px; left: 11px; right: auto; width: 4px; height: auto; transform-origin: top; }
    .route li { text-align: left; padding: 0 0 0 2.6rem; }
    .route li::before { left: 0; translate: 0 0; }
    @media (prefers-reduced-motion: no-preference) {
      @keyframes draw { from { transform: scaleY(0); } to { transform: scaleY(1); } }
    }
  }
</style>
</head>
<body>
<header>
  <div class="wrap">
    <strong>BMS Institute of Technology and Management</strong>
    <span>Faculty Development Programme on AWS cloud</span>
  </div>
</header>

<main class="wrap">
  <h1>Welcome to the AWS cloud FDP</h1>
  <p class="lead">This page is running on a server you built today, inside your own virtual network on AWS. Here is the path your request took to reach it.</p>

  <ol class="route" aria-label="Request path">
    <li>__STOP1__</li>
    <li>__STOP2__</li>
    <li>__SUBNET__<small>in demo-vpc</small></li>
    <li>This web server<small>Amazon EC2</small></li>
  </ol>

  <section class="server" aria-labelledby="served-by">
    <h2 id="served-by">Served by this instance</h2>
    <dl>
      <dt>Instance ID</dt><dd>__INSTANCE_ID__</dd>
      <dt>Availability Zone</dt><dd>__AZ__</dd>
      <dt>Private IP</dt><dd>__PRIVATE_IP__</dd>
      <dt>Instance type</dt><dd>__INSTANCE_TYPE__</dd>
    </dl>
  </section>
  <p class="note">Refresh this page later, when a load balancer sits in front of several servers, and watch these details change.</p>
</main>

<footer>
  <div class="wrap">Hands-on lab: VPC, subnets, route tables, NAT gateway and EC2</div>
</footer>
</body>
</html>
EOF

sed -i \
  -e "s|__INSTANCE_ID__|$INSTANCE_ID|" \
  -e "s|__AZ__|$AZ|" \
  -e "s|__PRIVATE_IP__|$PRIVATE_IP|" \
  -e "s|__INSTANCE_TYPE__|$INSTANCE_TYPE|" \
  -e "s|__SUBNET__|$SUBNET|" \
  -e "s|__STOP1__|$STOP1|" \
  -e "s|__STOP2__|$STOP2|" \
  /var/www/html/index.html
