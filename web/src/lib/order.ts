import { keccak256, toHex, type Hex } from "viem";

/**
 * Invoice model for InvoiceRail. The amount that must be paid comes from the
 * invoice registered on chain via InvoiceCheckout.createInvoice(orderId, amount),
 * never from a value the payer's browser invents. This module is the app-side
 * mirror of that registry: in production, replace the in-memory map with your
 * database / the on-chain `invoiceOf(orderId)` read.
 */
export interface Invoice {
  orderId: Hex;
  lines: { label: string; amount: string }[];
  total: string;
}

export const demoInvoice: Invoice = {
  orderId: "0x0000000000000000000000000000000000000000000000000000000000000000" as Hex,
  lines: [
    { label: "Consulting — invoice item", amount: "1.00" },
    { label: "Service fee", amount: "0.05" },
  ],
  total: "1.05",
};

/** Backwards-compatible alias used by older imports. */
export const demoOrder = demoInvoice;

const registry = new Map<string, Invoice>();

export function registerInvoice(invoice: Invoice): Invoice {
  registry.set(invoice.orderId.toLowerCase(), invoice);
  return invoice;
}

export function invoiceOf(orderId: Hex): Invoice {
  return registry.get(orderId.toLowerCase()) ?? { ...demoInvoice, orderId };
}

/**
 * What an invoice costs, decided by its registration, never by the payer's
 * request. The relayer only submits payments for exactly this amount.
 */
export function priceOf(orderId: Hex): string {
  return invoiceOf(orderId).total;
}

export function newOrderId(): Hex {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return keccak256(toHex(bytes));
}

/** Create a fresh invoice draft (unregistered until createInvoice is called on chain). */
export function newInvoice(total = demoInvoice.total, lines = demoInvoice.lines): Invoice {
  return registerInvoice({ orderId: newOrderId(), lines, total });
}

/** Short, human-friendly label for a bytes32 order id. */
export function orderLabel(orderId: Hex): string {
  return `#${orderId.slice(2, 6).toUpperCase()}-${orderId.slice(-4).toUpperCase()}`;
}

export function short(value: string, head = 6, tail = 4): string {
  return value.length > head + tail + 1 ? `${value.slice(0, head)}…${value.slice(-tail)}` : value;
}
