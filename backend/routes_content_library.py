from flask import Blueprint, request, jsonify
from functools import wraps
from datetime import datetime

from models_content_library import db, ContentModule, ModuleVersion


content_bp = Blueprint("content_library", __name__, url_prefix="/api/modules")


def get_jwt_payload():
    try:
        auth_header = request.headers.get("Authorization", "")
        if not auth_header:
            return None
        # For local/dev seeding allow any token but avoid invalid UUIDs
        return {"user_id": None, "role": "Admin"}
    except Exception:
        return None


def role_required(allowed_roles):
    def decorator(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            payload = get_jwt_payload()
            if not payload or payload.get("role") not in allowed_roles:
                return jsonify({"error": "Unauthorized"}), 403
            return f(*args, **kwargs)
        return wrapper
    return decorator


@content_bp.route("/", methods=["GET"])
def list_modules():
    q = request.args.get("q", "").strip()
    category = request.args.get("category", "").strip()
    query = ContentModule.query
    if category:
        query = query.filter(ContentModule.category == category)
    if q:
        like = f"%{q}%"
        query = query.filter((ContentModule.title.ilike(like)) | (ContentModule.body.ilike(like)))
    modules = query.order_by(ContentModule.updated_at.desc()).limit(500).all()
    return jsonify([m.serialize() for m in modules]), 200


@content_bp.route("/<module_id>", methods=["GET"])
def get_module(module_id):
    m = ContentModule.query.get(module_id)
    if not m:
        return jsonify({"error": "Not found"}), 404
    return jsonify(m.serialize()), 200


@content_bp.route("/", methods=["POST"])
@role_required(["Admin", "BDM"])
def create_module():
    payload = request.json or {}
    title = payload.get("title")
    category = payload.get("category", "Other")
    body = payload.get("body", "")
    is_editable = bool(payload.get("is_editable", False))
    user = get_jwt_payload() or {"user_id": None}
    if not title or not body:
        return jsonify({"error": "Missing title or body"}), 400
    m = ContentModule(title=title, category=category, body=body, created_by=user["user_id"], is_editable=is_editable)
    db.session.add(m)
    db.session.flush()
    v = ModuleVersion(module_id=m.id, version=1, snapshot=body, created_by=user["user_id"], note="Initial version")
    db.session.add(v)
    db.session.commit()
    return jsonify({"message": "created", "id": m.id}), 201


@content_bp.route("/<module_id>", methods=["PUT"])
def update_module(module_id):
    user = get_jwt_payload() or {}
    m = ContentModule.query.get(module_id)
    if not m:
        return jsonify({"error": "Not found"}), 404

    role = user.get("role")
    can_edit = role in ("Admin", "BDM")
    if not can_edit and not m.is_editable:
        return jsonify({"error": "Forbidden"}), 403

    payload = request.json or {}
    new_body = payload.get("body")
    new_title = payload.get("title")
    note = payload.get("note", "Edited")
    if new_body is None and new_title is None:
        return jsonify({"error": "No content to update"}), 400

    current_version = m.version or 1
    new_version = current_version + 1
    ver = ModuleVersion(module_id=m.id, version=new_version, snapshot=m.body, created_by=user.get("user_id"), note=note)
    db.session.add(ver)

    if new_body is not None:
        m.body = new_body
    if new_title is not None:
        m.title = new_title
    m.version = new_version
    m.updated_at = datetime.utcnow()
    db.session.add(m)
    db.session.commit()
    return jsonify({"message": "updated", "version": new_version}), 200


@content_bp.route("/<module_id>", methods=["DELETE"])
@role_required(["Admin"])
def delete_module(module_id):
    m = ContentModule.query.get(module_id)
    if not m:
        return jsonify({"error": "Not found"}), 404
    db.session.delete(m)
    db.session.commit()
    return jsonify({"message": "deleted"}), 200


@content_bp.route("/<module_id>/versions", methods=["GET"])
def list_versions(module_id):
    versions = ModuleVersion.query.filter_by(module_id=module_id).order_by(ModuleVersion.version.desc()).all()
    return jsonify([v.serialize() for v in versions]), 200


@content_bp.route("/<module_id>/revert", methods=["POST"])
@role_required(["Admin", "BDM"])
def revert_module(module_id):
    payload = request.json or {}
    to_version = int(payload.get("version", 0))
    if to_version <= 0:
        return jsonify({"error": "invalid version"}), 400
    old = ModuleVersion.query.filter_by(module_id=module_id, version=to_version).first()
    if not old:
        return jsonify({"error": "version not found"}), 404
    m = ContentModule.query.get(module_id)
    user = get_jwt_payload() or {"user_id": None}

    snapshot_ver = (m.version or 1) + 1
    snapshot = ModuleVersion(module_id=m.id, version=snapshot_ver, snapshot=m.body, created_by=user["user_id"], note=f"Snapshot before revert to v{to_version}")
    db.session.add(snapshot)

    m.body = old.snapshot
    m.version = snapshot_ver
    m.updated_at = datetime.utcnow()
    db.session.add(m)

    newv = ModuleVersion(module_id=m.id, version=snapshot_ver, snapshot=m.body, created_by=user["user_id"], note=f"Reverted to v{to_version}")
    db.session.add(newv)
    db.session.commit()
    return jsonify({"message": "reverted", "new_version": m.version}), 200


@content_bp.route("/<module_id>/insert", methods=["POST"])
@role_required(["Admin", "BDM"])
def insert_into_proposal(module_id):
    payload = request.json or {}
    proposal_id = payload.get("proposal_id")
    section_name = payload.get("section_name")
    if not proposal_id:
        return jsonify({"error": "proposal_id required"}), 400
    m = ContentModule.query.get(module_id)
    if not m:
        return jsonify({"error": "module not found"}), 404

    try:
        from models import ProposalSection
    except Exception:
        ProposalSection = None

    if ProposalSection is None:
        return jsonify({"message": "module fetched", "content": m.body, "title": m.title, "version": m.version}), 200

    sec = ProposalSection(proposal_id=proposal_id, section_name=section_name or m.title, content=m.body)
    db.session.add(sec)
    db.session.commit()
    return jsonify({"message": "inserted", "section_id": sec.id}), 200





