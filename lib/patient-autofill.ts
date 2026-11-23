export type PatientFormData = {
  id: string;
  full_name: string;
  age: number | null;
  date_of_birth: string | null;
  gender: string | null;
  acquisition_source: string | null;
  notes: string | null;
  phone: string;
  national_id: string;
  address: string;
};

function ageFromDateOfBirth(value: string | null | undefined): number | null {
  if (!value) return null;
  const dob = new Date(`${value}T00:00:00`);
  if (Number.isNaN(dob.getTime())) return null;
  const today = new Date();
  let age = today.getFullYear() - dob.getFullYear();
  const beforeBirthday = today.getMonth() < dob.getMonth() ||
    (today.getMonth() === dob.getMonth() && today.getDate() < dob.getDate());
  if (beforeBirthday) age -= 1;
  return age >= 0 && age <= 125 ? age : null;
}

/**
 * Fetches a selected patient by immutable ID. Private contact details are
 * deliberately fetched only for Reception/Admin; RLS remains authoritative.
 */
export async function fetchPatientFormData(client: any, patientId: string, role: string) {
  const patientResult = await client.from('patients')
    .select('id,organization_id,branch_id,full_name,age,date_of_birth,gender,acquisition_source,notes')
    .eq('id', patientId)
    .maybeSingle();
  if (patientResult.error) return { data: null as PatientFormData | null, error: patientResult.error };
  if (!patientResult.data) return { data: null as PatientFormData | null, error: new Error('لم يتم العثور على ملف المريض المحدد.') };

  let privateDetails: Record<string, string | null> = {};
  if (role === 'admin' || role === 'reception') {
    const privateResult = await client.from('patient_private_details')
      .select('phone,national_id,address')
      .eq('patient_id', patientId)
      .maybeSingle();
    if (privateResult.error) return { data: null as PatientFormData | null, error: privateResult.error };
    privateDetails = privateResult.data || {};
  }

  const patient = patientResult.data;
  const calculatedAge = ageFromDateOfBirth(patient.date_of_birth);
  return {
    data: {
      id: patient.id,
      full_name: patient.full_name,
      age: calculatedAge ?? patient.age ?? null,
      date_of_birth: patient.date_of_birth ?? null,
      gender: patient.gender ?? null,
      acquisition_source: patient.acquisition_source ?? null,
      notes: patient.notes ?? null,
      phone: privateDetails.phone ?? '',
      national_id: privateDetails.national_id ?? '',
      address: privateDetails.address ?? '',
    } as PatientFormData,
    error: null,
  };
}

function normalizePatientName(value: string): string {
  return String(value || '').trim().toLowerCase()
    .replace(/[\u0640\u064B-\u065F]/g, '')
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .replace(/\s+/g, ' ');
}

function normalizePatientPhone(value: string): string {
  return String(value || '').replace(/\D/g, '');
}

/**
 * Prevents avoidable duplicate creation by checking normalized name and,
 * where RLS allows it, normalized phone within the same organization/branch.
 */
export async function findExistingPatient(
  client: any,
  input: { organizationId: string; branchId: string; fullName: string; phone?: string; role: string; knownPatients?: any[] },
) {
  const name = normalizePatientName(input.fullName);
  const known = (input.knownPatients || []).find((patient) =>
    patient.branch_id === input.branchId && normalizePatientName(patient.full_name) === name,
  );
  if (known) return { data: known, error: null };

  const nameMatches = await client.from('patients')
    .select('id,organization_id,branch_id,full_name,age,date_of_birth,gender,acquisition_source,notes')
    .eq('organization_id', input.organizationId)
    .eq('branch_id', input.branchId)
    .limit(1000);
  if (nameMatches.error) return { data: null, error: nameMatches.error };
  const byName = (nameMatches.data || []).find((patient: any) =>
    patient.branch_id === input.branchId && normalizePatientName(patient.full_name) === name,
  );
  if (byName) return { data: byName, error: null };

  const normalizedPhone = normalizePatientPhone(input.phone || '');
  if (normalizedPhone && (input.role === 'admin' || input.role === 'reception')) {
    const privateRows = await client.from('patient_private_details')
      .select('patient_id,phone')
      .eq('organization_id', input.organizationId)
      .eq('branch_id', input.branchId)
      .limit(2000);
    if (privateRows.error) return { data: null, error: privateRows.error };
    const phoneMatch = (privateRows.data || []).find((row: any) =>
      normalizePatientPhone(row.phone || '') === normalizedPhone,
    );
    if (phoneMatch) {
      const patient = await client.from('patients')
        .select('id,organization_id,branch_id,full_name,age,date_of_birth,gender,acquisition_source,notes')
        .eq('id', phoneMatch.patient_id)
        .maybeSingle();
      if (patient.error) return { data: null, error: patient.error };
      if (patient.data) return { data: patient.data, error: null };
    }
  }
  return { data: null, error: null };
}
