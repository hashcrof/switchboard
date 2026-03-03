import React, { useState, useEffect } from "react";

interface Donation {
    id: string;
    firstname: string;
    lastname: string;
    amount: number;
    refcode: string;
    timestamp: Date;
}

function fmt$(n: number): string {
    if (n >= 1000) return `$${(n / 1000).toFixed(1)}K`;
    return `$${n.toLocaleString()}`;
}

function fmtTime(date: Date): string {
    const diff = Math.floor((Date.now() - date.getTime()) / 1000);
    if (diff < 60) return `${diff}s ago`;
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    return date.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

const DAY = 86_400_000;

export default function Dashboard() {
    const [donations, setDonations] = useState<Donation[]>([]);
    const [refcodeFilter, setRefcodeFilter] = useState<string>("all");

    useEffect(() => {
        const es = new EventSource("http://127.0.0.1:8000/stream");
        es.onopen = () => {
            console.log("Connection opened");
        }

        es.onmessage = (event) => {
            const donation: Donation = JSON.parse(event.data);
            donation.timestamp = new Date(donation.timestamp); // parse ISO string → Date
            setDonations(prev => [donation, ...prev].slice(0, 200));
        };

        es.onerror = () => {
            console.error("SSE connection lost, retrying...");
        };

        return () => es.close();
    }, []);

    const allRefCodes: string[] = donations.filter((item: Donation, index: number, self: Donation[]) =>
        index === self.findIndex((t) => t.refcode === item.refcode)
    ).map((d) => d.refcode);

    const filtered: Donation[]  = refcodeFilter === "all"
        ? donations
        : donations.filter(d => d.refcode === refcodeFilter);

    const now = Date.now();
    const total = filtered.reduce((s, d) => s + d.amount, 0);
    const last7 = filtered.filter(d => (now - d.timestamp.getTime()) < 7 * DAY).reduce((s, d) => s + d.amount, 0);
    const last1 = filtered.filter(d => (now - d.timestamp.getTime()) < DAY).reduce((s, d) => s + d.amount, 0);

    return (
        <div style={{ fontFamily: "system-ui, sans-serif", background: "#f9fafb", minHeight: "100vh", padding: 24 }}>

            <div style={{ marginBottom: 24 }}>
                <h1 style={{ fontSize: 22, fontWeight: 700, color: "#111", margin: 0 }}>Fundraising Dashboard</h1>
                <p style={{ fontSize: 13, color: "#888", marginTop: 4 }}>Live donation activity</p>
            </div>

            <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 12, marginBottom: 24 }}>
                {[
                    { label: "All-Time", value: fmt$(total), sub: `${filtered.length} donations` },
                    { label: "Last 7 Days", value: fmt$(last7) },
                    { label: "Last 24 Hours", value: fmt$(last1) },
                ].map(card => (
                    <div key={card.label} style={{ background: "#fff", border: "1px solid #e5e7eb", borderRadius: 8, padding: "16px 20px" }}>
                        <div style={{ fontSize: 12, color: "#888", marginBottom: 4 }}>{card.label}</div>
                        <div style={{ fontSize: 28, fontWeight: 700, color: "#111" }}>{card.value}</div>
                        {card.sub && <div style={{ fontSize: 12, color: "#aaa", marginTop: 2 }}>{card.sub}</div>}
                    </div>
                ))}
            </div>

            <div style={{ display: "flex", gap: 8, marginBottom: 16 }}>
                {["all", ...allRefCodes].map(rc => (
                    <button
                        key={rc}
                        onClick={() => setRefcodeFilter(rc)}
                        style={{
                            padding: "5px 12px", borderRadius: 6, fontSize: 12, cursor: "pointer",
                            border: "1px solid #e5e7eb",
                            background: refcodeFilter === rc ? "#111" : "#fff",
                            color: refcodeFilter === rc ? "#fff" : "#555",
                        }}
                    >
                        {rc}
                    </button>
                ))}
            </div>

            <div style={{ background: "#fff", border: "1px solid #e5e7eb", borderRadius: 8, overflow: "hidden" }}>
                <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
                    <thead>
                    <tr style={{ background: "#f9fafb", borderBottom: "1px solid #e5e7eb" }}>
                        {["Donor", "Refcode", "Amount", "Time"].map(h => (
                            <th key={h} style={{ padding: "10px 16px", textAlign: "left", fontWeight: 600, color: "#555", fontSize: 11, textTransform: "uppercase", letterSpacing: "0.05em" }}>{h}</th>
                        ))}
                    </tr>
                    </thead>
                    <tbody>
                    {filtered.slice(0, 50).map(d => (
                        <tr key={d.id} style={{ borderBottom: "1px solid #f3f4f6" }}>
                            <td style={{ padding: "10px 16px", color: "#111" }}>{d.firstname} {d.lastname}</td>
                            <td style={{ padding: "10px 16px", color: "#888", fontFamily: "monospace" }}>{d.refcode}</td>
                            <td style={{ padding: "10px 16px", fontWeight: 600, color: "#111" }}>${d.amount.toLocaleString()}</td>
                            <td style={{ padding: "10px 16px", color: "#aaa" }}>{fmtTime(d.timestamp)}</td>
                        </tr>
                    ))}
                    {filtered.length === 0 && (
                        <tr>
                            <td colSpan={4} style={{ padding: 32, textAlign: "center", color: "#aaa" }}>No donations found.</td>
                        </tr>
                    )}
                    </tbody>
                </table>
            </div>

        </div>
    );
}
