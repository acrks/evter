"use client";

import { FormEvent, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";

type Plan = { name: string; detail: string; status: "Set" | "Needs you" | "Planning" };

const plans: Plan[] = [
  { name: "Travel", detail: "8 of 12 arrivals are in", status: "Needs you" },
  { name: "Stay", detail: "Skyline House · 4 nights", status: "Set" },
  { name: "Supplies", detail: "3 things still unclaimed", status: "Needs you" },
  { name: "Activities", detail: "2 plans ready to RSVP", status: "Planning" },
  { name: "Dinner", detail: "Friday steakhouse is booked", status: "Set" },
  { name: "Expenses", detail: "Your total: $486", status: "Needs you" },
];

const dates = ["May 15", "May 22", "Jun 5"];
const destinations = ["Las Vegas", "Scottsdale", "Cabo"];

export default function Home() {
  const [view, setView] = useState<"welcome" | "auth" | "party">("welcome");
  const [authMode, setAuthMode] = useState<"sign-in" | "sign-up">("sign-in");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [notice, setNotice] = useState("");
  const [selectedDates, setSelectedDates] = useState<string[]>(["May 22"]);
  const [votes, setVotes] = useState<string[]>(["Las Vegas"]);
  const [claimed, setClaimed] = useState(false);
  const [rsvp, setRsvp] = useState<"in" | "out" | null>(null);
  const [tab, setTab] = useState("Overview");

  useEffect(() => {
    supabase?.auth.getSession().then(({ data }) => {
      if (data.session) setView("party");
    });
  }, []);

  function toggle(value: string, values: string[], setValues: (next: string[]) => void) {
    setValues(values.includes(value) ? values.filter((item) => item !== value) : [...values, value]);
  }

  async function authenticate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!supabase) return setNotice("Supabase configuration is not available yet.");
    const response = authMode === "sign-in"
      ? await supabase.auth.signInWithPassword({ email, password })
      : await supabase.auth.signUp({ email, password });
    if (response.error) return setNotice(response.error.message);
    if (authMode === "sign-up") return setNotice("Check your email to confirm your account, then sign in.");
    setView("party");
  }

  async function signInWithGoogle() {
    if (!supabase) return setNotice("Supabase configuration is not available yet.");
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: window.location.origin },
    });
    if (error) setNotice(error.message);
  }

  if (view === "party") {
    return <PartyDashboard
      tab={tab} setTab={setTab} selectedDates={selectedDates} toggleDate={(date) => toggle(date, selectedDates, setSelectedDates)}
      votes={votes} toggleVote={(destination) => toggle(destination, votes, setVotes)} claimed={claimed} setClaimed={setClaimed} rsvp={rsvp} setRsvp={setRsvp}
    />;
  }

  return (
    <main className="landing-shell">
      <nav className="topbar"><span className="brand">evter<span>.</span></span><button className="text-button" onClick={() => setView("auth")}>Sign in</button></nav>
      {view === "welcome" ? <>
        <section className="hero">
          <p className="eyebrow">PARTY PLANNING, MADE HUMAN</p>
          <h1>A better way to bring everyone <em>together.</em></h1>
          <p className="hero-copy">The bachelor party is supposed to be the fun part. Evter keeps the texts, tabs, spreadsheets, votes, and who-owes-what in one considered place.</p>
          <div className="hero-actions"><button className="primary-button" onClick={() => setView("auth")}>Sign in to your party <span>→</span></button><button className="quiet-button" onClick={() => { setAuthMode("sign-up"); setView("auth"); }}>Create an account</button></div>
        </section>
        <section className="ritual-card"><div><p className="eyebrow">ONE SHARED RHYTHM</p><h2>Less wrangling.<br />More celebrating.</h2></div><div className="mini-itinerary"><p><b>Thu</b><span>Land, check in, settle in</span></p><p><b>Fri</b><span>Golf at 10 · Dinner at 8</span></p><p><b>Sat</b><span>Pool day · House party</span></p></div></section>
      </> : <section className="auth-card">
        <button className="back-button" onClick={() => setView("welcome")}>← Back</button><p className="eyebrow">WELCOME IN</p><h1>{authMode === "sign-in" ? "Good to see you." : "Let’s get this party started."}</h1>
        <form onSubmit={authenticate}><label>Email<input type="email" value={email} onChange={(event) => setEmail(event.target.value)} required placeholder="you@example.com" /></label><label>Password<input type="password" value={password} onChange={(event) => setPassword(event.target.value)} required minLength={6} placeholder="At least 6 characters" /></label><button className="primary-button" type="submit">{authMode === "sign-in" ? "Sign in" : "Create account"} <span>→</span></button></form>
        <div className="divider">or</div><button className="oauth-button" onClick={signInWithGoogle}>Continue with Google</button>{notice && <p className="notice">{notice}</p>}<p className="auth-switch">{authMode === "sign-in" ? "New here?" : "Already have an account?"} <button onClick={() => { setAuthMode(authMode === "sign-in" ? "sign-up" : "sign-in"); setNotice(""); }}>{authMode === "sign-in" ? "Create one" : "Sign in"}</button></p>
      </section>}
    </main>
  );
}

function PartyDashboard({ tab, setTab, selectedDates, toggleDate, votes, toggleVote, claimed, setClaimed, rsvp, setRsvp }: { tab: string; setTab: (value: string) => void; selectedDates: string[]; toggleDate: (value: string) => void; votes: string[]; toggleVote: (value: string) => void; claimed: boolean; setClaimed: (value: boolean) => void; rsvp: "in" | "out" | null; setRsvp: (value: "in" | "out") => void }) {
  return <main className="app-shell"><header className="app-header"><button className="event-switcher">Jesse’s Vegas Weekend <span>⌄</span></button><span className="brand">evter<span>.</span></span><button className="avatar">AC</button></header><nav className="section-nav">{["Overview", "Travel", "Stay", "Supplies", "Plans", "Expenses", "Admin"].map((item) => <button key={item} className={tab === item ? "active" : ""} onClick={() => setTab(item)}>{item}</button>)}</nav>
    <section className="dashboard-heading"><div><p className="eyebrow">MAY 22–25 · LAS VEGAS</p><h1>Jesse’s last ride.</h1><p className="subtle">12 close friends, one excellent weekend.</p></div><div className="countdown"><b>43</b><span>days to go</span></div></section>
    <section className="overview-grid"><div className="plan-grid">{plans.map((plan) => <button className="plan-card" key={plan.name} onClick={() => setTab(plan.name === "Stay" ? "Stay" : plan.name)}><span className={`status ${plan.status.toLowerCase().replace(" ", "-")}`}>{plan.status}</span><h3>{plan.name}</h3><p>{plan.detail}</p><span className="arrow">→</span></button>)}</div>
      <aside className="side-stack"><section className="card vote-card"><p className="eyebrow">YOUR AVAILABILITY</p><h2>Which weekends work?</h2><div className="pill-row">{dates.map((date) => <button key={date} className={selectedDates.includes(date) ? "pill selected" : "pill"} onClick={() => toggleDate(date)}>{date}</button>)}</div><p className="helper">Votes stay private until the host finalizes.</p></section><section className="card vote-card"><p className="eyebrow">DESTINATION VOTE</p><h2>Where are you in?</h2>{destinations.map((destination) => <button className={votes.includes(destination) ? "choice selected" : "choice"} key={destination} onClick={() => toggleVote(destination)}><span>{destination}</span><span>{votes.includes(destination) ? "✓" : "+"}</span></button>)}</section></aside></section>
    <section className="lower-grid"><section className="card activity-card"><div><p className="eyebrow">SATURDAY · 1:00 PM</p><h2>Desert rally &amp; lunch</h2><p>Private off-road tour for the whole crew. $129 per person.</p></div><div className="rsvp-actions"><button className={rsvp === "in" ? "rsvp in chosen" : "rsvp in"} onClick={() => setRsvp("in")}>I’m in</button><button className={rsvp === "out" ? "rsvp out chosen" : "rsvp out"} onClick={() => setRsvp("out")}>Can’t make it</button></div></section><section className="card supply-card"><p className="eyebrow">SUPPLY RUN</p><h2>Tequila &amp; lime</h2><p>Still needed for the house.</p><button className={claimed ? "claim claimed" : "claim"} onClick={() => setClaimed(!claimed)}>{claimed ? "You’ve got it ✓" : "I’ll bring this"}</button></section></section>
  </main>;
}
