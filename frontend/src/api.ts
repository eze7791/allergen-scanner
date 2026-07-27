const BASE = '';
const SESSION_KEY = 'allergen_session';

export interface AuthSession {
  token: string;
  role: 'admin' | 'staff';
  restaurantId: number;
  restaurantName: string;
  joinCode: string;
}

export interface Allergen {
  id: number;
  name: string;
  description?: string;
}

export interface LinkedAllergen extends Allergen {
  note?: string;
}

export interface FoodItem {
  id: number;
  name: string;
  description?: string;
  category?: string;
  image_path?: string;
  allergens: LinkedAllergen[];
  may_contain_allergens: LinkedAllergen[];
}

export interface Recipe {
  id: number;
  name: string;
  description?: string;
  category?: string;
  allergens: LinkedAllergen[];
  may_contain_allergens: LinkedAllergen[];
}

export interface SuggestResult {
  items: { id: number; name: string; category?: string }[];
  recipes: { id: number; name: string; category?: string; type: string }[];
}

export function getSession(): AuthSession | null {
  const raw = localStorage.getItem(SESSION_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

export function setSession(session: AuthSession) {
  localStorage.setItem(SESSION_KEY, JSON.stringify(session));
  window.dispatchEvent(new Event('auth-changed'));
}

export function clearSession() {
  localStorage.removeItem(SESSION_KEY);
  window.dispatchEvent(new Event('auth-changed'));
}

function toSession(data: {
  token: string;
  role: 'admin' | 'staff';
  restaurant_id: number;
  restaurant_name: string;
  join_code: string;
}): AuthSession {
  return {
    token: data.token,
    role: data.role,
    restaurantId: data.restaurant_id,
    restaurantName: data.restaurant_name,
    joinCode: data.join_code,
  };
}

async function authFetch(path: string, options: RequestInit = {}): Promise<Response> {
  const session = getSession();
  const headers = new Headers(options.headers);
  if (options.body && !(options.body instanceof FormData)) {
    headers.set('Content-Type', 'application/json');
  }
  if (session) headers.set('Authorization', `Bearer ${session.token}`);
  const r = await fetch(`${BASE}${path}`, { ...options, headers });
  if (r.status === 401) {
    clearSession();
  }
  return r;
}

// --- Auth ---

export async function createRestaurant(name: string, adminUsername: string, adminPassword: string): Promise<AuthSession> {
  const r = await authFetch('/restaurants', {
    method: 'POST',
    body: JSON.stringify({ name, admin_username: adminUsername, admin_password: adminPassword }),
  });
  const data = await r.json();
  if (!r.ok) throw new Error(data.detail || 'Could not create restaurant');
  return toSession(data);
}

export async function joinRestaurant(joinCode: string): Promise<AuthSession> {
  const r = await authFetch('/restaurants/join', {
    method: 'POST',
    body: JSON.stringify({ join_code: joinCode }),
  });
  const data = await r.json();
  if (!r.ok) throw new Error(data.detail || 'Could not join restaurant');
  return toSession(data);
}

export async function adminLogin(username: string, password: string): Promise<AuthSession> {
  const r = await authFetch('/auth/admin-login', {
    method: 'POST',
    body: JSON.stringify({ username, password }),
  });
  const data = await r.json();
  if (!r.ok) throw new Error(data.detail || 'Invalid username or password');
  return toSession(data);
}

// --- Allergens ---

export async function getAllergens(): Promise<Allergen[]> {
  const r = await authFetch('/allergens');
  return r.json();
}

export async function createAllergen(name: string, description?: string): Promise<Allergen> {
  const r = await authFetch('/allergens', {
    method: 'POST',
    body: JSON.stringify({ name, description: description || '' }),
  });
  return r.json();
}

export async function updateAllergen(id: number, data: { name?: string; description?: string }): Promise<Allergen> {
  const r = await authFetch(`/allergens/${id}`, { method: 'PUT', body: JSON.stringify(data) });
  return r.json();
}

export async function deleteAllergen(id: number): Promise<void> {
  await authFetch(`/allergens/${id}`, { method: 'DELETE' });
}

// --- Food items ---

export async function getFoodItems(): Promise<FoodItem[]> {
  const r = await authFetch('/food-items');
  return r.json();
}

export async function getFoodItem(id: number): Promise<FoodItem> {
  const r = await authFetch(`/food-items/${id}`);
  return r.json();
}

export async function updateFoodItem(
  id: number,
  data: Partial<Pick<FoodItem, 'name' | 'description' | 'category' | 'image_path'>> & {
    allergen_ids?: number[];
    may_contain_allergen_ids?: number[];
  }
): Promise<FoodItem> {
  const r = await authFetch(`/food-items/${id}`, { method: 'PUT', body: JSON.stringify(data) });
  return r.json();
}

export async function deleteFoodItem(id: number): Promise<void> {
  await authFetch(`/food-items/${id}`, { method: 'DELETE' });
}

export async function suggest(q: string): Promise<SuggestResult> {
  const r = await authFetch(`/food-items/suggest?q=${encodeURIComponent(q)}`);
  return r.json();
}

export async function scanImage(
  file: File
): Promise<{ image_path: string; detected_allergens: Allergen[]; all_allergens: Allergen[] }> {
  const fd = new FormData();
  fd.append('file', file);
  const r = await authFetch('/scan', { method: 'POST', body: fd });
  return r.json();
}

export async function createFoodItem(data: {
  name: string;
  description?: string;
  category?: string;
  image_path?: string;
  allergen_ids: number[];
  may_contain_allergen_ids?: number[];
}): Promise<FoodItem> {
  const r = await authFetch('/food-items', { method: 'POST', body: JSON.stringify(data) });
  return r.json();
}

// --- Recipes ---

export async function getRecipes(): Promise<Recipe[]> {
  const r = await authFetch('/recipes');
  return r.json();
}

export async function getRecipe(id: number): Promise<Recipe> {
  const r = await authFetch(`/recipes/${id}`);
  return r.json();
}

export async function createRecipe(data: {
  name: string;
  description?: string;
  category?: string;
  allergen_ids: number[];
  may_contain_allergen_ids?: number[];
}): Promise<Recipe> {
  const r = await authFetch('/recipes', { method: 'POST', body: JSON.stringify(data) });
  return r.json();
}

export async function updateRecipe(
  id: number,
  data: {
    name?: string;
    description?: string;
    category?: string;
    allergen_ids?: number[];
    may_contain_allergen_ids?: number[];
  }
): Promise<Recipe> {
  const r = await authFetch(`/recipes/${id}`, { method: 'PUT', body: JSON.stringify(data) });
  return r.json();
}

export async function deleteRecipe(id: number): Promise<void> {
  await authFetch(`/recipes/${id}`, { method: 'DELETE' });
}
